# Input, arithmetic, random and save contract review

This pass inspected the original Thumb instructions for the entries below and
compared them with maintained C. It did not run the implementation or compare
emulator behavior. No source correction was established in this sample.

| Native entries | Source | Confirmed contract |
| --- | --- | --- |
| `08003BC4`, `08003BF4`, `08003C1C` | `src/frame_input.c` | Frame wait clears only flag bit zero, waits for it, resets the callback, then polls input. Polling retains the full 16-bit complement of KEYINPUT. Changed input resets the repeat timer to ten; unchanged input decrements the byte and repeats when zero, resetting to three. |
| `08003A6C`, `08003A84`, `08003AB4`, `08003AF0` | `src/hardware.c` | Fixed-point multiply/divide truncate toward zero. The long multiply uses the native 64-bit multiplication helper; the long division uses a signed 64-bit scaled numerator. Results retain the native low halfword or word. |
| `0803458C`, `080345B4`, `080345E4`, `0803460C`, `08034628` | `src/random.c` | The high seed bit is returned before shifting. A set high bit applies XOR `0x10000`, then shifts and sets bit zero. Byte generation consumes eight bits, high bit first. Equal byte bounds consume no randomness; halfword bounds always consume two bytes. Reversed bounds use signed remainder. |
| `08006068`, `080060EC`, `08006128` | `src/save_storage.c` | Signature failure or commit marker above two is invalid. Valid markers combine with both checksum results using the preserved twelve-entry outcome table. Checksum validation loads and unpacks primary then backup, so detection changes state. Preparation repairs the selected copy or initializes invalid storage. Interrupted-save repair only repairs. |
| `08006150`, `08006188`, `080061A8`, `080061C8`, `080061F4`, `08006220`, `08006248` | `src/save_storage.c` | Payload size is `0x80A`; primary starts at SRAM offset `0x40`, backup at `0x4020`, checksums at `0x401E`/`0x7FFE`. Save packs/checksums once and commits primary before backup. Repair uses the intact copy's stored checksum. |
| `0800627C`, `0800634C`, `08006368`, `08006384`, `080063A0`, `08006418..0800650E`, `08036C30` | `src/save_storage.c` | Initialization writes four 8 KiB zero blocks, initializes state and writes both saves before the fifteen-byte signature. Commit markers follow the original order. Verified writes allow at most three attempts; callers ignore failures as in the ROM. |

The SRAM API expresses byte-copy, checksum and commit semantics. CPU instruction
relocation, bus timing, interrupts and failure behavior on real hardware have
not been execution-compared. This review does not independently audit every
hardware or software-arithmetic routine.
