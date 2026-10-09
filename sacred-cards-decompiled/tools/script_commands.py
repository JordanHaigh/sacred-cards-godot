"""AY7E script token boundaries recovered from 0x08031E40.

Offline decoder: retains operands, languages and unknown commands. It does not
execute effects or claim that lexical decoding implements the game's VM.
"""
# (operand bytes after the two-byte prefix, descriptive operation, called routine)
COMMANDS={
 '#0':(0,'line_or_page_position',None), '#1':(0,'wait_for_input',0x08032460),
 '#2':(0,'reset_dialogue_layout',None), '#3':(0,'enter_choice_state',None),
 '#4':(2,'set_portrait_parameters',0x08031B88), '#5':(0,'enter_state_4',None),
 '#6':(1,'set_event_flag',0x08033D64), '#7':(1,'test_event_flag',0x08033DB0),
 '#8':(1,'duel_and_branch_on_result',0x08017B84), '#9':(2,'add_one_card',0x0800431C),
 '@0':(4,'actor_command_0',0x08032944), '@1':(4,'actor_command_1',0x08032A50),
 '@2':(0,'call_08006150',0x08006150), '@3':(2,'audio_player_parameter',0x08021F10),
 '@4':(2,'actor_command_4',0x08032B64), '@5':(2,'actor_command_5',0x08032C24),
 '@6':(1,'call_08032AB0',0x08032AB0), '@7':(1,'wait_update_cycles',0x08003BC4),
 '@8':(1,'play_audio',0x08021E50), '@9':(1,'compare_scene_cell_low_byte',0x080311B0),
 '^0':(1,'select_text_state',0x08033D28), '^1':(0,'stop_two_audio_players',0x08021ECC),
 '^2':(1,'call_08033A14',0x08033A14), '^3':(1,'call_08032CE4',0x08032CE4),
 '^4':(0,'reset_text_graphics',0x08031AF8), '^5':(2,'call_08032AFC',0x08032AFC),
 '^6':(1,'consume_operand',None),
}

def decode(window):
    """Return tokens and termination status; never silently skip unknown syntax."""
    tokens=[];pos=0;language=None
    if window.startswith(b'Z'):
        return [dict(offset=0,kind='terminal_node',raw='5a')], 'terminal_Z'
    while pos<len(window):
        start=pos;c=window[pos]
        if c==0:
            tokens.append(dict(offset=pos,kind='end',raw='00'));return tokens,'nul_at_token_boundary'
        if c in b'#@^':
            if pos+2>len(window):return tokens,'truncated_prefix'
            key=window[pos:pos+2].decode('ascii','replace')
            if key not in COMMANDS:
                tokens.append(dict(offset=pos,kind='unknown_command',raw=window[pos:pos+2].hex()))
                return tokens,'unknown_command'
            n,name,handler=COMMANDS[key];end=pos+2+n
            if end>len(window):return tokens,'truncated_operand'
            operands=list(window[pos+2:end])
            token=dict(offset=pos,kind='command',command=key,operation=name,operands=operands,
                       language=language,raw=window[pos:end].hex(),handler=f'0x{handler:08X}' if handler else None)
            if key in ('#9','@3'):token['operand_u16_le']=int.from_bytes(window[pos+2:end],'little')
            if key=='@8':token['audio_id']=operands[0];token['suppressed_by_handler']=operands[0] in (111,122,123)
            if key in ('#6','#7'):token['event_flag']=operands[0]
            tokens.append(token);pos=end;continue
        if c==ord('$'):
            if pos+2>len(window) or window[pos+1] not in b'0123456':
                tokens.append(dict(offset=pos,kind='unknown_language_marker',raw=window[pos:pos+2].hex()))
                return tokens,'unknown_language_marker'
            marker=window[pos+1]-48;language=marker if marker<6 else None
            tokens.append(dict(offset=pos,kind='language',language=language,marker=marker,raw=window[pos:pos+2].hex()))
            pos+=2;continue
        # Original glyph path consumes two bytes whenever the high bit is set.
        text=[]
        while pos<len(window) and window[pos]!=0 and window[pos] not in b'#@^$':
            n=2 if window[pos]&128 else 1
            if pos+n>len(window):return tokens,'truncated_glyph'
            raw=window[pos:pos+n]
            if n==1:text.append(chr(raw[0]))
            else:
                try:text.append(raw.decode('shift_jis'))
                except UnicodeDecodeError:text.append(''.join(f'\\x{b:02X}' for b in raw))
            pos+=n
        tokens.append(dict(offset=start,kind='text',language=language,text=''.join(text),raw=window[start:pos].hex()))
    return tokens,'window_boundary'
