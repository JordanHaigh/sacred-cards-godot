/* AY7E SRAM lifecycle 08006068..0800650E and byte driver 080369C0..08036C6A.
 * Semantic reconstruction, not linked/matched or execution-compared. Preserves
 * the observed write order, three-attempt retry policy and ignored failures.
 * Stack/RAM code relocation is replaced with direct C byte loops; instruction
 * placement and hardware timing are not reproduced by this parameterized API.
 */
#include "save_storage.h"
#include <stddef.h>
#define PAYLOAD_SIZE 0x80Au
#define PRIMARY_DATA 0x40u
#define BACKUP_DATA 0x4020u
#define PRIMARY_CHECKSUM 0x401Eu
#define BACKUP_CHECKSUM 0x7FFEu
extern void PackSavePayload(uint8_t *);
extern void UnpackSavePayload(const uint8_t *);
extern uint16_t SavePayloadChecksum(const uint8_t *);
extern void InitializeNewGame(void); /* new-game subsystem initialization */
/* Native storage writes exactly 15 characters, excluding the ROM NUL. */
static const uint8_t save_signature[15]="020322_DM7_KCEJ";

static void SramWait(struct SaveStorage *s)
{
    *s->wait_control=(*s->wait_control & 0xFFFCu) | 3u;
}
/* Read routine copied from 08036ACC to RAM 0201EFF8 by 08036B98. */
static void ReadSram(struct SaveStorage *s, uint32_t offset, uint8_t *out, uint32_t size)
{
    SramWait(s);
    for (uint32_t i=0; i<size; ++i) out[i]=s->sram[offset+i];
}
/* 080369C0 and 08036B0C have the same byte-copy semantics. */
static void WriteSram(struct SaveStorage *s, uint32_t offset, const uint8_t *in, uint32_t size)
{
    SramWait(s);
    for (uint32_t i=0; i<size; ++i) s->sram[offset+i]=in[i];
}
/* 08036B4C is copied to RAM 0201EF58; 08036A00 is copied to the stack by
 * 08036A30. Both return zero or the native address of the first mismatch.
 */
static uint32_t CompareSram(struct SaveStorage *s, uint32_t offset, const uint8_t *in, uint32_t size)
{
    SramWait(s);
    for (uint32_t i=0; i<size; ++i) {
        uint8_t stored=s->sram[offset+i];
        if (stored!=in[i]) return 0x0E000000u+offset+i;
    }
    return 0;
}
/* Both retry wrappers (08036A94/08036C30) use at most three attempts. */
static uint32_t WriteVerified(struct SaveStorage *s, uint32_t offset, const uint8_t *in, uint32_t size)
{
    uint32_t error=0;
    for (unsigned attempt=0; attempt<3; ++attempt) {
        WriteSram(s,offset,in,size);
        error=CompareSram(s,offset,in,size);
        if (!error) break;
    }
    return error;
}
static void SetCommitState(struct SaveStorage *s, uint8_t value)
{
    (void)WriteVerified(s,0,&value,1);
}
static void WriteChecksum(struct SaveStorage *s, uint32_t address, uint16_t value)
{
    uint8_t bytes[2]={(uint8_t)value,(uint8_t)(value>>8)};
    (void)WriteVerified(s,address,bytes,2);
}
static uint16_t ReadChecksum(struct SaveStorage *s, uint32_t address)
{
    uint8_t bytes[2]; ReadSram(s,address,bytes,2);
    return (uint16_t)(bytes[0] | (uint16_t)bytes[1]<<8);
}
/* 080061C8/080061F4: even validation calls restore all RAM descriptor regions. */
void LoadPrimarySave(struct SaveStorage *s)
{
    ReadSram(s,PRIMARY_DATA,s->payload,PAYLOAD_SIZE);
    UnpackSavePayload(s->payload);
}
void LoadBackupSave(struct SaveStorage *s)
{
    ReadSram(s,BACKUP_DATA,s->payload,PAYLOAD_SIZE);
    UnpackSavePayload(s->payload);
}
static uint8_t SignatureMatches(struct SaveStorage *s)
{
    uint8_t signature[15]; ReadSram(s,1,signature,15);
    for (unsigned i=0; i<15; ++i) if (signature[i]!=save_signature[i]) return 0;
    return 1;
}
/* 08006068. Return 0=new/invalid, 1=ready, 2=repair backup, 3=repair primary.
 * Do not turn this into a pure predicate: checksum checks load both payloads.
 */
uint32_t DetectSaveState(struct SaveStorage *s)
{
    if (!SignatureMatches(s)) return 0;
    uint8_t state; ReadSram(s,0,&state,1);
    if (state>=3) return 0;
    LoadPrimarySave(s);
    uint16_t primary_sum=SavePayloadChecksum(s->payload);
    uint8_t primary_ok=primary_sum==ReadChecksum(s,PRIMARY_CHECKSUM);
    LoadBackupSave(s);
    uint16_t backup_sum=SavePayloadChecksum(s->payload);
    uint8_t backup_ok=backup_sum==ReadChecksum(s,BACKUP_CHECKSUM);
    static const uint8_t outcomes[12]={0,3,2,1,0,3,0,3,0,0,2,2};
    return outcomes[(state<<2)|(primary_ok<<1)|backup_ok];
}
/* 08006150: pack once, checksum once, primary then backup then clean marker.
 * Native caller ignores every write/verification failure; preserved here.
 */
void SaveGameCopies(struct SaveStorage *s)
{
    PackSavePayload(s->payload);
    uint16_t sum=SavePayloadChecksum(s->payload);
    SetCommitState(s,1);
    (void)WriteVerified(s,PRIMARY_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,PRIMARY_CHECKSUM,sum);
    SetCommitState(s,2);
    (void)WriteVerified(s,BACKUP_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,BACKUP_CHECKSUM,sum);
    SetCommitState(s,0);
}
/* 08006220/08006248 repair one copy using the other's stored checksum. */
static void RepairBackup(struct SaveStorage *s)
{
    LoadPrimarySave(s);
    uint16_t sum=ReadChecksum(s,PRIMARY_CHECKSUM);
    SetCommitState(s,2);
    (void)WriteVerified(s,BACKUP_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,BACKUP_CHECKSUM,sum);
    SetCommitState(s,0);
}
static void RepairPrimary(struct SaveStorage *s)
{
    LoadBackupSave(s);
    uint16_t sum=ReadChecksum(s,BACKUP_CHECKSUM);
    SetCommitState(s,1);
    (void)WriteVerified(s,PRIMARY_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,PRIMARY_CHECKSUM,sum);
    SetCommitState(s,0);
}
/* 0800627C: four 8 KiB zero writes, new-game globals, both save copies, signature.
 * Header is committed only after payloads/checksums have been written.
 */
void InitializeSaveStorage(struct SaveStorage *s)
{
    for (unsigned i=0; i<8192; ++i) s->payload[i]=0;
    for (uint32_t offset=0; offset<32768; offset+=8192)
        (void)WriteVerified(s,offset,s->payload,8192);
    InitializeNewGame();
    PackSavePayload(s->payload);
    uint16_t sum=SavePayloadChecksum(s->payload);
    SetCommitState(s,1);
    (void)WriteVerified(s,PRIMARY_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,PRIMARY_CHECKSUM,sum);
    SetCommitState(s,2);
    (void)WriteVerified(s,BACKUP_DATA,s->payload,PAYLOAD_SIZE);
    WriteChecksum(s,BACKUP_CHECKSUM,sum);
    SetCommitState(s,3);
    (void)WriteVerified(s,1,save_signature,15);
    SetCommitState(s,0);
}
/* 080060EC: invalid/unknown states initialize; state 1 is a no-op. */
void PrepareSaveState(struct SaveStorage *s, uint8_t state)
{
    switch (state) {
    case 1: break;
    case 2: RepairBackup(s); break;
    case 3: RepairPrimary(s); break;
    default: InitializeSaveStorage(s); break;
    }
}
/* 08006128: unlike PrepareSaveState, this does not initialize invalid storage. */
void RepairInterruptedSave(struct SaveStorage *s)
{
    uint8_t state=(uint8_t)DetectSaveState(s);
    if (state==2) RepairBackup(s);
    else if (state==3) RepairPrimary(s);
}

/* Native fixed-address adapter for script command @2 (08006150). */
void SaveCurrentGame(void) {
    struct SaveStorage storage={(volatile uint8_t *)0x0E000000,(uint8_t *)0x02018800,(volatile uint16_t *)0x04000204};
    SaveGameCopies(&storage);
}

/*08036B98/08006270: native byte-driver installation. Parameterized read/
 *compare above use C loops; this retains the original relocated entry setup.*/
extern uint8_t gSramReadCode[64],gSramCompareCode[76]; /*0201EFF8/0201EF58*/
extern uintptr_t gSramReadEntry,gSramCompareEntry; /*020237DC/E0*/
void InitializeSramAccess(void)
{
    const uint16_t *read=(const uint16_t *)0x08036ACC,*compare=(const uint16_t *)0x08036B4C;
    for(unsigned i=0;i<32;++i)((uint16_t *)gSramReadCode)[i]=read[i];
    gSramReadEntry=(uintptr_t)gSramReadCode|1;
    for(unsigned i=0;i<38;++i)((uint16_t *)gSramCompareCode)[i]=compare[i];
    gSramCompareEntry=(uintptr_t)gSramCompareCode|1;
    volatile uint16_t *wait=(volatile uint16_t *)0x04000204;*wait=(*wait&0xFFFC)|3;
}

/*08036938/3695C: older relocated read driver. Source/destination ordering
 * follows the ROM byte loop. Relocation itself is not needed for source reuse.*/
void CopyLegacySramBytes(const volatile uint8_t *source,uint8_t *destination,uint32_t size)
{ while(size--) *destination++=*source++; }
void ReadLegacySramBytes(const volatile uint8_t *source,uint8_t *destination,uint32_t size)
{ volatile uint16_t *wait=(volatile uint16_t *)0x04000204;*wait=(*wait&0xFFFC)|3;CopyLegacySramBytes(source,destination,size); }
/*080231CC: intentionally copies a whole64KiB ROM span beginning at the
 * eleven-byte signature view, then restores the eleven-byte tail.*/
void FillLegacySramSignature(void)
{
    const uint8_t *source=(const uint8_t *)0x08D4BD1C;volatile uint8_t *out=(volatile uint8_t *)0x0E000000;
    volatile uint16_t *wait=(volatile uint16_t *)0x04000204;*wait=(*wait&0xFFFC)|3;
    for(uint32_t i=0;i<0x10000;++i)out[i]=source[i];*wait=(*wait&0xFFFC)|3;
    for(uint32_t i=0;i<11;++i)out[0xFFF0+i]=source[i];
}
