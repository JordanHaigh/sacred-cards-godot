#ifndef AY7E_SAVE_STORAGE_H
#define AY7E_SAVE_STORAGE_H
#include <stdint.h>
/* Parameterized host/native memory view, not the original ABI. Payload buffer
 * must have 8192 bytes because new-save initialization uses it for SRAM erase.
 */
struct SaveStorage {
    volatile uint8_t *sram; /* native 0E000000, 32768 bytes */
    uint8_t *payload;      /* native 02018800, at least 8192 bytes */
    volatile uint16_t *wait_control; /* native 04000204 */
};
uint32_t DetectSaveState(struct SaveStorage *);
void SaveGameCopies(struct SaveStorage *);
void LoadPrimarySave(struct SaveStorage *);
void LoadBackupSave(struct SaveStorage *);
void InitializeSaveStorage(struct SaveStorage *);
void PrepareSaveState(struct SaveStorage *, uint8_t state);
void RepairInterruptedSave(struct SaveStorage *);
#endif
