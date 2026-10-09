#ifndef AY7E_NATIVE_STATE_H
#define AY7E_NATIVE_STATE_H
/* Byte-layout records recovered from AY7E accesses. Address fields are uint32_t
 * provenance values, never host-sized pointers. Decode little-endian fields
 * explicitly on a non-little-endian host; do not cast unaligned byte buffers.
 * Reserved bytes remain part of the records and are not implicitly zeroed.
 * These types describe data contracts without installing a native RAM layout. */
#include <stdint.h>
#include <stddef.h>
#pragma pack(push,1)
struct Ay7eDuelCell {
    uint16_t card;
    int8_t stage;
    uint8_t status_bits,flags,reserved[3];
};
struct Ay7eDuelSide { uint16_t grave_card;uint8_t flags,reserved; };
struct Ay7eDuelSnapshot {
    struct Ay7eDuelCell board[4][5],hands[2][5];
    uint8_t terrain,reserved[3];
    struct Ay7eDuelSide sides[2];
};
struct Ay7eDuelDeck { uint16_t cards[40];uint8_t remaining,reserved[3]; };
struct Ay7eCollectionMenu {
    uint16_t selection;
    uint8_t sort,detail,choice,reserved[7];
};
struct Ay7ePlayerDeckState {
    uint32_t cost;
    int8_t selection;
    uint8_t sort,detail,sort_popup,count,reserved;
};
struct Ay7eShopMenu {
    int16_t first_row,row_count;
    uint8_t column,row,ring,sort,choice,reserved;
};
struct Ay7eCardSortState {
    uint32_t cards_address,unused_word;
    uint16_t count;
    uint8_t method,reserved;
};
struct Ay7eCardSortRecord {
    uint16_t card,reserved;
    uint32_t key_low,key_high;
};
struct Ay7eCardMetadata {
    uint32_t name_address,name_copy_address,description_address,cost;
    uint16_t card,attack,defense;
    uint8_t type,attribute,level,frame,metadata1a,metadata1b,metadata1c,metadata1d;
};
struct Ay7eRuntimeActor {
    int16_t sprite;
    uint8_t pose,reserved03;
    int16_t x,y,height;
    uint16_t scene_cell;
    uint8_t walk_phase,reserved0d[3];
    uint32_t script_a,script_b;
    uint8_t movement,reserved19;
    int16_t wander_timer;
    uint8_t flags,reserved1d[3];
};
struct Ay7eFollowerEntry {
    uint8_t pose,reserved01;
    int16_t x,y;
    uint8_t reserved06[2];
};
struct Ay7eBattleCombatant {
    uint16_t card,attack,defense,life;
    uint8_t attribute,row,column,reserved;
};
struct Ay7eBattleCalculation {
    struct Ay7eBattleCombatant a,b;
    uint8_t command,result_flags,owner_a,owner_b;
};
struct Ay7eBattleDisplaySide {
    uint16_t card,initial_life,final_life,attack,defense;
    uint8_t attribute,reserved;
};
struct Ay7eBattleDisplay {
    struct Ay7eBattleDisplaySide a,b;
    uint8_t result;
};
struct Ay7eDuelCursor {
    uint8_t column,row,saved_column,saved_row,mode,menu_choice;
};
struct Ay7eSceneHeader { uint16_t scene,variant,spawn,reserved; };
struct Ay7eOpponentRecord {
    /* Native AI also reads these first four bytes as one word and then
     * truncates to a halfword. Terrain is a distinct byte at +2. */
    uint16_t identifier;
    uint8_t terrain,reserved03;
    uint32_t deck_address,normal_rewards_address,shop_rewards_address,special_rewards_address;
    uint16_t player_starting_life,opponent_starting_life;
    uint32_t capacity_reward;
    uint16_t money_roll_min,money_roll_max;
    uint8_t money_scale,reserved21[3];
    uint32_t music;
};
struct Ay7eScriptState {
    uint16_t portrait,reserved02;
    uint32_t cursor,glyph_position;
    uint8_t state,choice_layout,reserved0e[2];
    uint32_t text_address,next_false_address,next_true_address;
    uint16_t wait_counter;
    uint8_t branch_flags,reserved1f;
    uint16_t card,reserved22,reserved24;
    uint8_t embedded_text_index,reserved27;
    int16_t blink_index,blink_ticks,mouth_index,mouth_ticks;
    uint16_t speaking;
    uint8_t portrait_flags,dirty;
};
struct Ay7eDuelTextState {
    uint32_t cursor,glyph_position;
    uint8_t state,reserved09[3];
    uint32_t text_address;
    uint16_t blink,working,card,other,number,other_number;
    uint8_t index,reserved1d[3];
};
struct Ay7eOamEntry { uint16_t attr0,attr1,attr2,affine_or_padding; };
/* Byte zero supplies duration in battle frame lists. Portrait composition
 * uses count/+4 and does not interpret byte zero as a timing value. */
struct Ay7eSpriteFrame { uint8_t duration_or_tag,count;uint16_t reserved;uint32_t objects_address; };
struct Ay7eScriptNode { uint32_t text_address,next_false_address,next_true_address; };
struct Ay7eSaveRegion { uint32_t ram_address,size; };
#pragma pack(pop)
#define AY7E_SIZE(type,n) _Static_assert(sizeof(struct type)==(n),#type " native size")
AY7E_SIZE(Ay7eDuelCell,8);AY7E_SIZE(Ay7eDuelSide,4);AY7E_SIZE(Ay7eDuelDeck,84);
AY7E_SIZE(Ay7eDuelSnapshot,252);
AY7E_SIZE(Ay7eCollectionMenu,12);AY7E_SIZE(Ay7ePlayerDeckState,10);AY7E_SIZE(Ay7eShopMenu,10);
AY7E_SIZE(Ay7eCardSortState,12);AY7E_SIZE(Ay7eCardSortRecord,12);AY7E_SIZE(Ay7eCardMetadata,30);
AY7E_SIZE(Ay7eRuntimeActor,32);AY7E_SIZE(Ay7eFollowerEntry,8);AY7E_SIZE(Ay7eBattleCalculation,28);
AY7E_SIZE(Ay7eBattleCombatant,12);AY7E_SIZE(Ay7eBattleDisplaySide,12);AY7E_SIZE(Ay7eSceneHeader,8);
AY7E_SIZE(Ay7eBattleDisplay,25);AY7E_SIZE(Ay7eDuelCursor,6);AY7E_SIZE(Ay7eOpponentRecord,40);
AY7E_SIZE(Ay7eScriptState,52);AY7E_SIZE(Ay7eDuelTextState,32);AY7E_SIZE(Ay7eOamEntry,8);
AY7E_SIZE(Ay7eSpriteFrame,8);AY7E_SIZE(Ay7eScriptNode,12);AY7E_SIZE(Ay7eSaveRegion,8);
#undef AY7E_SIZE
#define AY7E_OFFSET(type,field,n) _Static_assert(offsetof(struct type,field)==(n),#type "." #field " native offset")
AY7E_OFFSET(Ay7eDuelSnapshot,hands,0xA0);AY7E_OFFSET(Ay7eDuelSnapshot,terrain,0xF0);
AY7E_OFFSET(Ay7eDuelSnapshot,sides,0xF4);AY7E_OFFSET(Ay7eRuntimeActor,script_a,0x10);
AY7E_OFFSET(Ay7eDuelCell,stage,2);AY7E_OFFSET(Ay7eDuelCell,status_bits,3);AY7E_OFFSET(Ay7eDuelCell,flags,4);
AY7E_OFFSET(Ay7eDuelSide,flags,2);AY7E_OFFSET(Ay7eDuelDeck,remaining,0x50);
AY7E_OFFSET(Ay7eCollectionMenu,sort,2);AY7E_OFFSET(Ay7eCollectionMenu,choice,4);
AY7E_OFFSET(Ay7ePlayerDeckState,selection,4);AY7E_OFFSET(Ay7ePlayerDeckState,count,8);
AY7E_OFFSET(Ay7eShopMenu,column,4);AY7E_OFFSET(Ay7eShopMenu,ring,6);AY7E_OFFSET(Ay7eShopMenu,choice,8);
AY7E_OFFSET(Ay7eCardSortState,count,8);AY7E_OFFSET(Ay7eCardSortState,method,0xA);
AY7E_OFFSET(Ay7eCardSortRecord,key_low,4);AY7E_OFFSET(Ay7eCardSortRecord,key_high,8);
AY7E_OFFSET(Ay7eRuntimeActor,movement,0x18);AY7E_OFFSET(Ay7eRuntimeActor,flags,0x1C);
AY7E_OFFSET(Ay7eRuntimeActor,x,4);AY7E_OFFSET(Ay7eRuntimeActor,scene_cell,0xA);
AY7E_OFFSET(Ay7eRuntimeActor,walk_phase,0xC);AY7E_OFFSET(Ay7eRuntimeActor,wander_timer,0x1A);
AY7E_OFFSET(Ay7eFollowerEntry,x,2);AY7E_OFFSET(Ay7eFollowerEntry,y,4);
AY7E_OFFSET(Ay7eCardMetadata,card,0x10);AY7E_OFFSET(Ay7eCardMetadata,type,0x16);
AY7E_OFFSET(Ay7eBattleCalculation,b,0xC);AY7E_OFFSET(Ay7eBattleCalculation,command,0x18);
AY7E_OFFSET(Ay7eBattleCalculation,owner_a,0x1A);AY7E_OFFSET(Ay7eBattleDisplay,result,0x18);
AY7E_OFFSET(Ay7eBattleDisplaySide,attribute,0xA);AY7E_OFFSET(Ay7eDuelCursor,mode,4);
AY7E_OFFSET(Ay7eOpponentRecord,terrain,2);AY7E_OFFSET(Ay7eOpponentRecord,deck_address,4);
AY7E_OFFSET(Ay7eOpponentRecord,player_starting_life,0x14);AY7E_OFFSET(Ay7eOpponentRecord,capacity_reward,0x18);
AY7E_OFFSET(Ay7eOpponentRecord,music,0x24);AY7E_OFFSET(Ay7eScriptState,blink_index,0x28);
AY7E_OFFSET(Ay7eScriptState,text_address,0x10);AY7E_OFFSET(Ay7eScriptState,dirty,0x33);
AY7E_OFFSET(Ay7eDuelTextState,index,0x1C);
AY7E_OFFSET(Ay7eSpriteFrame,objects_address,4);AY7E_OFFSET(Ay7eScriptNode,next_true_address,8);
#undef AY7E_OFFSET
/* Only meanings established by consumers are named. Other bits stay raw. */
enum Ay7eDuelCellFlags {
    AY7E_CELL_ATTACK_LOCK=1,AY7E_CELL_DEFENSE=2,AY7E_CELL_FACE_UP=16
};
enum Ay7eSideFlags { AY7E_SIDE_ATTACK_RESTRICTION_MASK=3,AY7E_SIDE_SUMMONED=8 };
#endif
