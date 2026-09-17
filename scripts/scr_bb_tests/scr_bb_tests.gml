// Opt-in checks execute the real GML with the actual imported school.
function bb_test_assert(_ok, _message) {
    global.test_total += 1;
    if (!_ok) {
        global.test_failed += 1;
        show_debug_message("BB_TEST_FAIL: " + _message);
    }
}

function bb_test_loading_complete(_load) {
    var _g=global.G;
    bb_test_assert(_g.mode==global.test_loading_mode,"loading preserves selected mode "+global.test_loading_mode);
    bb_test_assert(ds_map_size(global.floors)==682 && array_length(_g.doors)==23
        && !bb_blocked_world(_g.px,_g.pz,_g.radius,true),"school restarts safely after animated loading "+_g.mode);
    bb_test_assert(global.path_ready && global.path_grid.build_phase==2
        && array_length(_g.npcs)==6 && _g.move_latched,"loading completes navigation and actors before gameplay "+_g.mode);
    bb_test_assert(_load.presented>4 && _load.frame_changes>1,
        "loading animation advances during actual school construction "+_g.mode
        +" draws="+string(_load.presented)+" changes="+string(_load.frame_changes));
    bb_test_assert(_g.nb_t==0 && !_g.spoop_mode && _g.notebooks==0,
        "gameplay remains stopped while loading "+_g.mode);
    show_debug_message("BB_PROFILE_LOAD: "+_g.mode+" seconds="+string(_load.time)+" peak_us="+string(_load.peak_us));
}

function bb_test_menu_source() {
    var _menu=global.P.menu,_keys=variable_struct_get_names(_menu.buttons);
    bb_test_assert(sprite_get_width(spr_title)==640 && sprite_get_height(spr_title)==480,
        "original spr_title remains the 640x480 main-menu background");
    bb_test_assert(array_length(_keys)==18,"source main menu imports all 18 interactive visual states");
    for (var _i=0;_i<array_length(_keys);_i++) {
        var _button=_menu.buttons[$ _keys[_i]];
        var _normal=global.PS[$ _button.normal.texture],_selected=global.PS[$ _button.selected.texture];
        bb_test_assert(sprite_exists(_normal) && sprite_exists(_selected)
            && _button.normal.crop[2]==sprite_get_width(_normal)
            && _button.normal.crop[3]==sprite_get_height(_normal)
            && _button.selected.crop[2]==sprite_get_width(_selected)
            && _button.selected.crop[3]==sprite_get_height(_selected),
            "menu button preserves full source canvas across visual states "+_keys[_i]);
    }
    var _start=_menu.buttons.start.rect,_exit=_menu.buttons[$ "exit"].rect;
    var _start_hit=_menu.buttons.start.hit,_exit_hit=_menu.buttons[$ "exit"].hit;
    bb_test_assert(_start[0]==192 && _start[1]==392 && _start[2]==256 && _start[3]==128,
        "START uses the source MainMenu RectTransform");
    bb_test_assert(_exit[0]>543 && _exit[1]==-32 && _menu.buttons.start.preserve
        && _start_hit[2]<_start[2]*.5 && _start_hit[3]<_start[3]*.5
        && _exit_hit[2]<_exit[2]*.6 && _exit_hit[3]<_exit[3]*.6,
        "main buttons draw at source alignment but only visible art is interactive");
    var _story_bg=_menu.backgrounds.story.rect,_credits_bg=_menu.backgrounds.credits.rect;
    var _story_hit=_menu.buttons.story.hit,_endless_hit=_menu.buttons.endless.hit;
    bb_test_assert(_story_bg[0]==0 && _story_bg[1]==0 && _story_bg[2]==640 && _story_bg[3]==480
        && _credits_bg[0]==0 && _credits_bg[1]==0 && _credits_bg[2]==640 && _credits_bg[3]==480,
        "Story and Credits retain full 640x480 source pages");
    bb_test_assert(_story_hit[0]==_menu.buttons.story.rect[0]
        && _story_hit[1]==_menu.buttons.story.rect[1]
        && _story_hit[2]==_menu.buttons.story.rect[2]
        && _story_hit[3]==_menu.buttons.story.rect[3]
        && _endless_hit[0]==_menu.buttons.endless.rect[0]
        && _endless_hit[1]==_menu.buttons.endless.rect[1]
        && _endless_hit[2]==_menu.buttons.endless.rect[2]
        && _endless_hit[3]==_menu.buttons.endless.rect[3]
        && _story_hit[0]+_story_hit[2]>_menu.text.story.rect[0]+_menu.text.story.rect[2]*.5
        && _endless_hit[0]<_menu.text.endless.rect[0]+_menu.text.endless.rect[2]*.5,
        "mode source raycast rectangles include their adjacent hover text");
    bb_test_assert(_menu.slider.min==.1 && _menu.slider.max==10
        && _menu.slider.track[0]==250 && _menu.slider.track[1]==390,
        "options sensitivity slider retains source range and track");
    bb_test_assert(abs(_menu.text.story.font_size-26.9946)<.001
        && abs(_menu.text.endless.font_size-30.369)<.001
        && _menu.text.controls.font_size==24 && _menu.text.controls.line_spacing==16,
        "menu TMP sizes include each source RectTransform scale");
    var _font=global.P.yctp_font;
    var _story_glyphs=bb_yctp_text_layout(_menu.text.story.value,_menu.text.story);
    var _story_underlines=bb_yctp_underline_layout(_story_glyphs,_menu.text.story);
    var _story_thickness=_font.underline_thickness*_menu.text.story.font_size/_font.size;
    bb_test_assert(abs(_font.underline_offset+4.207031)<=.000001
        && abs(_font.underline_thickness-2.050781)<=.000001
        && array_length(_story_underlines)>=2
        && abs((_story_underlines[0][3]-_story_underlines[0][1])-_story_thickness)<=.0001
        && _story_underlines[0][1]>_menu.text.story.rect[1],
        "mode hover underline uses the source TMP offset and thickness on screen count="
        +string(array_length(_story_underlines))+" thickness="+string(_story_underlines[0][3]-_story_underlines[0][1])
        +" expected="+string(_story_thickness)+" y="+string(_story_underlines[0][1]));
    var _mouse_turn=bb_mouse_turn_radians(120,2),_mouse_expected=24*pi/180;
    bb_test_assert(abs(_mouse_turn-_mouse_expected)<=.000001,
        "mouse turning maps frame mouse displacement through source axis and degree units actual="
        +string(_mouse_turn)+" expected="+string(_mouse_expected)
        +" axis="+string(_menu.slider.input_axis_sensitivity));
    var _endless_value=_menu.text.endless.value+"\nHigh Score: 999999 Notebooks";
    var _endless_fit=bb_menu_endless_text_node(_endless_value);
    var _endless_glyphs=bb_yctp_text_layout(_endless_value,_endless_fit),_endless_bottom=-1000000;
    for (var _i=0;_i<array_length(_endless_glyphs);_i++) {
        var _glyph=_endless_glyphs[_i];
        _endless_bottom=max(_endless_bottom,_glyph.y+_glyph.src[3]*_glyph.scale);
    }
    bb_test_assert(_endless_bottom<=_menu.buttons.play_back.hit[1]-4
        && _endless_fit.rect[1]>=_menu.text.story.rect[1]+_menu.text.story.rect[3]+4,
        "Endless description and high score stay clear of Story text and Back button");
    var _load=_menu.loading;
    bb_test_assert(array_length(_load.frames)==47 && abs(_load.duration-1.0208334)<=.00001
        && _load.text.value=="LOAD","loading imports source spin loop and LOAD label");
    bb_test_assert(abs(_load.rect[0]+_load.rect[2]*.5-320)<.001
        && abs(_load.rect[1]+_load.rect[3]*.5-240)<.001
        && abs(_load.rect[2]-166.0321)<.001,"loading head retains centered source scale");
    bb_test_assert(bb_loading_texture(0)!=bb_loading_texture(.25)
        && bb_loading_texture(.25)==bb_loading_texture(.25+_load.duration),
        "loading animation changes frames and loops at original duration");
}

function bb_run_selftests() {
    if (!variable_global_exists("test_total")) { global.test_total=0;global.test_failed=0; }
    var _saved = variable_clone(global.G);
    var _g = global.G;
    _g.notebooks = 7;
    bb_test_assert(array_length(_g.doors) == 23, "23 authored doors");
    bb_test_assert(array_length(_g.notebooks_list) == 7, "7 authored notebooks");
    bb_test_assert(ds_map_size(global.floors) == 682, "682 floor tiles");
    bb_test_menu_source();
    var _gameplay=json_parse(bb_read_text("school_gameplay.json"));
    var _quarter_spawn=_gameplay.quarter_spawn,_quarter=undefined,_quarter_matches=0;
    bb_test_assert(_quarter_spawn.min_index==1 && _quarter_spawn.max_index==15
        && array_length(_quarter_spawn.locations)==15
        && _quarter_spawn.locations[0].source_id=="5811"
        && _quarter_spawn.locations[14].source_id=="8901",
        "random quarter imports source AI locations 1 through 15");
    for (var _i=0;_i<array_length(_quarter_spawn.locations);_i++) {
        var _point=_quarter_spawn.locations[_i];
        bb_test_assert(_point.index==_i+1 && bb_on_floor(_point.x,_point.z)
            && !bb_blocked_world(_point.x,_point.z,.05,true),
            "quarter fixed spawn is reachable "+string(_point.index));
    }
    for (var _i=0;_i<array_length(_g.items);_i++) {
        if (_g.items[_i].source_id==_quarter_spawn.source_id) _quarter=_g.items[_i];
    }
    if (!is_undefined(_quarter)) {
        for (var _i=0;_i<array_length(_quarter_spawn.locations);_i++) {
            var _point=_quarter_spawn.locations[_i];
            if (_quarter.spawn_index==_point.index && _quarter.x==_point.x && _quarter.z==_point.z
                && _quarter.pickup_y==_point.y+_quarter_spawn.offset_y) _quarter_matches+=1;
        }
    }
    bb_test_assert(!is_undefined(_quarter) && _quarter_matches==1,
        "scene quarter starts at exactly one source-selected fixed location");
    var _tex = variable_struct_get_names(global.map_textures);
    for (var _i = 0; _i < array_length(_tex); _i++) {
        bb_test_assert(sprite_exists(global.map_textures[$ _tex[_i]]), "texture loaded: " + _tex[_i]);
    }
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        var _label = global.map.doors[_i].source_name;
        _d.open = false;
        _d.locked = true;
        _d.lock_cd = 15;
        bb_test_assert(bb_blocked_world(_d.cx, _d.cz, 0.28, true), _label + " blocks player when locked");
        bb_test_assert(bb_blocked_world(_d.cx, _d.cz, 0.3, false), _label + " blocks NPC when locked");
        _d.locked = false;
        _d.lock_cd = 0;
        _d.open = true;
        bb_test_assert(!bb_blocked_world(_d.cx, _d.cz, 0.35, true), _label + " clear opening");
        var _nx = (_d.side == "e") ? 1 : ((_d.side == "w") ? -1 : 0);
        var _nz = (_d.side == "s") ? 1 : ((_d.side == "n") ? -1 : 0);
        for (var _sign = -1; _sign <= 1; _sign += 2) {
            var _x = _d.cx - _nx * 0.7 * _sign, _z = _d.cz - _nz * 0.7 * _sign;
            var _p = bb_move_slide(_x, _z, _nx * 1.4 * _sign, _nz * 1.4 * _sign, 0.28, true);
            bb_test_assert(bb_dist2(_p[0], _p[1], _d.cx + _nx * 0.7 * _sign, _d.cz + _nz * 0.7 * _sign) < 0.001,
                _label + " player crosses side " + string(_sign));
        }
        // Confirm the renderer's exact plane and collision share the same bounds.
        for (var _vi = 0; _vi < 4; _vi++) {
            var _v = _d.v[_vi];
            bb_test_assert(_v[0] >= _d.bounds[0] - 0.001 && _v[0] <= _d.bounds[3] + 0.001
                && _v[2] >= _d.bounds[2] - 0.001 && _v[2] <= _d.bounds[5] + 0.001, _label + " vertex alignment");
        }
    }
    // Portal navigation must cross the offset classroom doors at high frame rates.
    var _rates = [30, 60, 144];
    for (var _ri = 0; _ri < 3; _ri++) {
        for (var _di = 0; _di < array_length(_g.doors); _di++) {
            var _d = _g.doors[_di];
            var _nx = (_d.side == "e") ? 2 : ((_d.side == "w") ? -2 : 0);
            var _nz = (_d.side == "s") ? 2 : ((_d.side == "n") ? -2 : 0);
            for (var _sign = 0; _sign <= 1; _sign++) {
                var _x = _d.x + _nx * _sign, _z = _d.z + _nz * _sign;
                var _tx = _d.x + _nx * (1 - _sign), _tz = _d.z + _nz * (1 - _sign);
                for (var _step = 0; _step < _rates[_ri] * 2; _step++) {
                    var _p = bb_nav_advance(_x, _z, _tx, _tz, 3 / _rates[_ri], 0.3, true);
                    _x = _p[0]; _z = _p[1];
                    if (bb_dist2(_x, _z, _tx, _tz) < 0.01) break;
                }
                bb_test_assert(bb_dist2(_x, _z, _tx, _tz) < 0.01,
                    global.map.doors[_di].source_name + " nav " + string(_rates[_ri]) + "fps side " + string(_sign));
            }
        }
    }
    // Travel from spawn to every notebook using actual navigation and collision.
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        var _x = 0, _z = 2;
        for (var _step = 0; _step < 1200; _step++) {
            var _p = bb_nav_advance(_x, _z, _n.x, _n.z, 0.3, 0.3, true);
            if (bb_dist2(_p[0], _p[1], _x, _z) < 0.000001) break;
            _x = _p[0]; _z = _p[1];
            if (bb_dist2(_x, _z, _n.x, _n.z) < 0.1) break;
        }
        // Notebook centers sit above solid desks. Verify the route reaches
        // a standable approach and that the actual pickup ray hits the book.
        bb_test_assert(bb_dist2(_x, _z, _n.x, _n.z) < 1.05 * 1.05,
            "notebook route " + string(_i) + " ended at " + string(_x) + "," + string(_z));
        _g.px = _x; _g.pz = _z;
        _g.yaw = arctan2(_x - _n.x, _z - _n.z);
        var _hit = bb_interaction_target(2);
        bb_test_assert(_hit.kind == "notebook" && _hit.index == _i, "notebook pickup ray clears its desk " + string(_i));
    }
    // A half-wall adjacent to the first classroom must remain solid.
    bb_test_assert(bb_blocked_world(-1, -4.5, 0.28, true), "first classroom half-wall stays solid");
    _g.px = 0; _g.pz = -3.5; _g.yaw = pi * 0.5;
    _g.doors[8].open = false;
    bb_test_assert(bb_interaction_target(2).kind == "door", "first classroom crosshair hits door");
    // Exercise new item state without keyboard simulation.
    _g.inv = [1, -1, -1]; _g.inv_sel = 0;
    bb_test_assert(bb_use_item() && _g.stamina == 200 && _g.inv[0] == -1, "zesty consumption");
    _g.inv[0] = 7;
    bb_use_item();
    var _alarm_tick = _g.alarms[0].sound;
    bb_test_assert(_alarm_tick != -1 && audio_is_playing(_alarm_tick)
        && global.P.details.alarm_drop.w == 2.56, "dropped alarm uses source size and ticking loop");
    _g.baldi_active = true; _g.hear_pri = 0;
    bb_update_item_effects(29);
    bb_test_assert(!_g.alarms[0].rang, "alarm waits 30 seconds");
    bb_update_item_effects(1);
    bb_test_assert(_g.alarms[0].rang && _g.hear_pri == 8 && !audio_is_playing(_alarm_tick)
        && _g.alarms[0].sound != _alarm_tick, "alarm stops ticking, rings, and gets hearing priority");
    _g.anti_hear = 30;
    var _hear_x = _g.hear_x;
    bb_hear_pri(100, 100, 9);
    bb_test_assert(_g.hear_x == _hear_x, "anti hearing suppresses sound targets");
    bb_start_playtime();
    bb_rope_tick(2.1, false);
    bb_test_assert(_g.play_need == 5 && _g.rope_delay > 1, "missed rope resets progress");
    var _oops = _g.rope_wait_sound, _oops_delay = _g.rope_delay, _oops_time = _g.rope_wait_time;
    bb_rope_tick(1, false);
    bb_test_assert(_g.rope_wait_sound == _oops && _g.rope_delay == _oops_delay
        && _g.rope_wait_time <= _oops_time && _g.rope_wait_time > 0,
        "missed rope waits for the complete Oops instance");
    if (_oops != -1) audio_stop_sound(_oops); else _g.rope_wait_time = .01;
    bb_rope_tick(.02, false);
    bb_test_assert(_g.rope_wait_sound == -1 && _g.rope_time > .9, "rope restarts after Oops finishes");
    _g.inv[0] = 9;
    bb_test_assert(bb_use_item() && _g.play_lock == 0, "scissors release rope");
    bb_test_soda_audio();
    global.G = _saved;
    bb_refresh_details();
    bb_test_yctp_state();
    bb_test_debug_menu();
    bb_test_pause_state();
    bb_test_scene_details();
    bb_test_stationary_navigation();
    bb_test_principal_routes();
    bb_test_detention();
    bb_test_restored_gameplay();
    bb_test_crafters_gaze();
    bb_test_end_states();
    bb_test_ai_profile();
    audio_stop_all();
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    show_debug_message("BB_TEST_LOGIC: " + string(global.test_total) + " checks, " + string(global.test_failed) + " failures");
}

function bb_test_pause_state() {
    var _original=global.G;
    global.G=variable_clone(_original);
    var _g=global.G;
    _g.state="play";_g.gameover=false;_g.win=false;_g.debug.open=false;
    _g.pause=false;_g.detention=12;_g.mouse_ready=true;
    var _tone=bb_sound_play(snd_alarm);
    bb_pause_set(true);
    bb_test_assert(_g.pause && audio_is_paused(_tone),"pause opens the source quit confirmation and pauses audio");
    var _before=[_g.px,_g.pz,_g.yaw,_g.nb_t,_g.baldi_cd,_g.stamina];
    bb_game_update(.1);
    bb_test_assert(_g.detention==12 && _g.px==_before[0] && _g.pz==_before[1]
        && _g.yaw==_before[2] && _g.nb_t==_before[3] && _g.baldi_cd==_before[4]
        && _g.stamina==_before[5],"pause freezes movement, AI, stamina and world timers");
    var _input={mx:193.6,my:289.95,down:false,up:false,yes:false,no:false,escape:false};
    bb_pause_input(0,_input);bb_pause_input(.3,_input);
    bb_test_assert(_g.pause_hover==0 && bb_pause_frame(_g.pause_time)>0 && _g.detention==12,
        "YES nod animates with unscaled time while the world remains paused");
    _input.mx=457.36248;bb_pause_input(0,_input);
    bb_test_assert(_g.pause_hover==1 && _g.pause_time==0,"switching to NO resets its shake animation");
    bb_pause_input(.3,_input);
    bb_test_assert(bb_pause_frame(_g.pause_time)>0,"NO shake advances while paused");
    _input.mx=320;_input.my=420;bb_pause_input(.1,_input);
    bb_test_assert(_g.pause_hover==-1 && _g.pause_time==0,"leaving the heads restores their idle frame");
    _input.mx=193.6;_input.my=289.95;_input.down=true;
    bb_test_assert(bb_pause_input(0,_input)=="","pause button waits for mouse release");
    _input.down=false;_input.up=true;_input.mx=457.36248;
    bb_test_assert(bb_pause_input(0,_input)=="","dragging from YES to NO does not activate either button");
    _input.up=false;_input.down=true;bb_pause_input(0,_input);
    _input.down=false;_input.up=true;
    var _action=bb_pause_input(0,_input);
    bb_test_assert(_action=="resume","clicking NO resumes the paused game");
    bb_pause_action(_action);
    bb_test_assert(!_g.pause && !_g.mouse_ready && !audio_is_paused(_tone),
        "resume restores audio and discards the first locked-mouse delta");
    bb_pause_set(true);_input.up=false;_input.mx=193.6;_input.down=true;
    bb_pause_input(0,_input);_input.down=false;_input.up=true;
    bb_test_assert(bb_pause_input(0,_input)=="title","clicking YES requests the main menu");
    _input.up=false;_input.yes=true;
    bb_test_assert(bb_pause_input(0,_input)=="title","source Y shortcut confirms quitting to title");
    _input.yes=false;_input.no=true;
    bb_test_assert(bb_pause_input(0,_input)=="resume","source N shortcut resumes");
    _input.no=false;_input.escape=true;
    bb_test_assert(bb_pause_input(0,_input)=="resume","Escape closes the quit confirmation");
    bb_pause_set(false);_g.state="yctp";
    bb_test_assert(!bb_pause_set(true) && !_g.pause,"learning screen does not open the pause menu");
    bb_test_assert(array_length(global.P.pause.frame_times)==47
        && sprite_get_number(global.PS.pause_nod)==47 && sprite_get_number(global.PS.pause_shake)==47
        && bb_pause_frame(.01)==0 && bb_pause_frame(.3)==bb_pause_frame(1.1),
        "pause heads preserve 47 source frames and the 0.8-second loop");
    audio_stop_all();global.G=_original;
    window_mouse_set_locked(false);window_set_cursor(cr_default);
}

function bb_test_restored_gameplay() {
    var _original=global.G,_high=global.high_books;
    global.G=variable_clone(_original);
    var _g=global.G;
    _g.debug.god=true;_g.debug.no_rules=false;_g.state="play";
    var _pickup=_g.notebooks_list[0];_g.px=_pickup.x+2.5;_g.pz=_pickup.z;
    bb_test_assert(!bb_pickup_in_range(_pickup),"notebook uses source ten-unit pickup distance");
    _pickup=_g.items[0];_g.px=_pickup.x+1.5;_g.pz=_pickup.z;
    bb_test_assert(bb_pickup_in_range(_pickup),"nearby item is inside source pickup distance");
    _g.notebooks=7;
    for (var _i=0;_i<array_length(_g.doors);_i++) { _g.doors[_i].locked=false;_g.doors[_i].lock_cd=0;_g.doors[_i].open=true; }
    for (var _i=0;_i<array_length(_g.props);_i++) {
        var _prop=_g.props[_i];
        if (_prop.kind!="soda" && _prop.kind!="zesty") continue;
        var _found=false;
        for (var _angle=0;_angle<360;_angle+=45) {
            _g.px=_prop.x+lengthdir_x(1.5,_angle);_g.pz=_prop.z+lengthdir_y(1.5,_angle);
            if (bb_blocked_world(_g.px,_g.pz,_g.radius,true)) continue;
            _g.yaw=arctan2(_g.px-_prop.x,_g.pz-_prop.z);
            var _hit=bb_interaction_target(2);
            if (_hit.kind=="prop" && _hit.index==_i) { _found=true;break; }
        }
        bb_test_assert(_found,"vending machine front can be targeted "+string(_i));
        _g.inv=[5,-1,-1];_g.inv_sel=0;
        bb_test_assert(_found && bb_use_item() && _g.inv[0]==(_prop.kind=="soda"?4:1),"quarter buys from solid machine "+string(_i));
    }
    var _principal=undefined,_bully=undefined,_playtime=undefined;
    for (var _i=0;_i<array_length(_g.npcs);_i++) {
        var _n=_g.npcs[_i];
        if (_n.kind=="principal") _principal=_n;
        if (_n.kind=="bully") _bully=_n;
        if (_n.kind=="playtime") _playtime=_n;
    }
    var _prize=undefined;
    for (var _i=0;_i<array_length(_g.npcs);_i++) if (_g.npcs[_i].kind=="prize") _prize=_g.npcs[_i];
    var _view_a=bb_prize_view_sprite(_prize,_prize.x+1,_prize.z),_view_b=bb_prize_view_sprite(_prize,_prize.x-1,_prize.z);
    bb_test_assert(array_length(_prize.source.views)==16 && _view_a!=_view_b,"1st Prize uses sixteen source direction sprites");
    _g.px=0;_g.pz=-14;_g.yaw=0;_g.prin_chase=false;_g.guilt=1;_g.guilt_type="running";
    _principal.x=0;_principal.z=-12;_principal.cool=0;_principal.stare=0;_principal.sees=true;
    bb_ai_principal(_principal,.49);
    bb_test_assert(!_g.prin_chase,"principal requires half a second of visible guilt");
    bb_ai_principal(_principal,.02);
    bb_test_assert(_g.prin_chase,"principal chases after sustained rule break");
    _g.guilt=0;_g.prin_chase=false;_principal.sees=false;_principal.bully_seen=false;
    _principal.x=0;_principal.z=-12;_bully.x=0;_bully.z=-14;_bully.mode="active";_bully.guilt=10;
    bb_voice_clear("principal");
    bb_ai_principal(_principal,.01);bb_ai_principal(_principal,.01);
    bb_test_assert(array_length(_g.voices.principal.queue)==1 && _g.voices.principal.queue[0]==global.S.clips[$ _principal.source.audio.audNoBullying],"principal announces bullying once per pursuit");
    _principal.x=0;_principal.z=-14.2;bb_ai_principal(_principal,.01);
    bb_test_assert(_bully.mode=="hidden","principal removes guilty bully on contact");
    _playtime.x=_g.px;_playtime.z=_g.pz;_g.audio_log=[];
    bb_start_playtime();
    bb_test_assert(_g.audio_log[0].clip==global.S.clips[$ _playtime.source.audio.aud_ReadyGo],"rope starts source Ready Go voice");
    bb_rope_tick(2.1,false);
    bb_test_assert(_g.audio_log[array_length(_g.audio_log)-1].clip==global.S.clips[$ _playtime.source.audio.aud_Oops],"missed rope plays Oops voice");
    _g.inv=[9,-1,-1];_g.inv_sel=0;bb_use_item();
    bb_test_assert(_g.play_lock==0 && _g.audio_log[array_length(_g.audio_log)-1].clip==global.S.clips[$ _playtime.source.audio.aud_Sad],"cut rope releases player and disappoints Playtime");
    bb_test_assert(abs(_playtime.cool-15)<.001,"Playtime keeps the source fifteen-second post-rope cooldown");
    var _contact=bb_grid_recover_position(_g.px,_g.pz,.3);
    _g.px=_contact[0];_g.pz=_contact[1];
    var _away=_contact;
    for (var _angle=0;_angle<360;_angle+=45) {
        var _candidate=[_contact[0]+lengthdir_x(2,_angle),_contact[1]+lengthdir_y(2,_angle)];
        if (!bb_blocked_world(_candidate[0],_candidate[1],.3,true)) {_away=_candidate;break;}
    }
    bb_test_assert(bb_dist2(_away[0],_away[1],_contact[0],_contact[1])>1,
        "Playtime cooldown check finds a legal separation point");
    _playtime.x=_g.px;_playtime.z=_g.pz;_playtime.cool=.01;_playtime.touch=false;_playtime.sees=false;
    bb_ai_playtime(_playtime,.005);
    _playtime.x=_g.px;_playtime.z=_g.pz;
    bb_ai_playtime(_playtime,.01);
    bb_test_assert(_g.play_lock==0,"Playtime contact made during cooldown does not trigger when cooldown expires");
    _playtime.x=_away[0];_playtime.z=_away[1];bb_ai_playtime(_playtime,0);
    _playtime.x=_g.px;_playtime.z=_g.pz;bb_ai_playtime(_playtime,0);
    bb_test_assert(_g.play_lock==1,"Playtime triggers after leaving and re-entering contact");
    bb_end_playtime();
    _g.mode="endless";_g.spoop_mode=false;_g.notebooks=1;_g.baldi_active=false;
    bb_yctp_open();
    for (var _i=0;_i<3;_i++) { _g.yctp_input=string(_g.yctp_ans);bb_yctp_submit(); }
    bb_yctp_close();
    bb_test_assert(!_g.spoop_mode && !_g.baldi_active,"perfect first Endless notebook does not start pursuit");
    _g.notebooks=2;bb_yctp_open();
    for (var _i=0;_i<2;_i++) { _g.yctp_input=string(_g.yctp_ans);bb_yctp_submit(); }
    bb_test_assert(_g.yctp_corrupt,"Endless second notebook has the impossible third problem");
    _g.yctp_input="0";bb_yctp_submit();bb_yctp_close();
    _g.notebooks=8;_g.baldi_anger=3;_g.exit_open=false;bb_yctp_open();
    var _all_solvable=true;
    for (var _i=0;_i<3;_i++) { _all_solvable=_all_solvable && !_g.yctp_corrupt;_g.yctp_input=string(_g.yctp_ans);bb_yctp_submit(); }
    bb_yctp_close();
    bb_test_assert(_all_solvable && _g.baldi_anger==2 && !_g.exit_open,"later Endless books are solvable, reduce anger and never raise exits");
    bb_yctp_open();var _anger=_g.baldi_anger,_temp=_g.baldi_extra;
    _g.yctp_input="99999";bb_yctp_submit();
    bb_test_assert(_g.baldi_anger==_anger+1 && _g.baldi_extra==_temp,"every Endless wrong answer increases permanent anger");
    bb_yctp_close();
    var _book=_g.notebooks_list[0];_book.taken=true;_book.respawn=120;
    _g.px=_book.x;_g.pz=_book.z;bb_update_notebook_respawns(60);
    bb_test_assert(_book.respawn==120 && _book.taken,"Endless notebook timer pauses near player");
    _g.px=_book.x+20;bb_update_notebook_respawns(119);
    bb_test_assert(_book.taken && _book.respawn==1,"Endless notebook waits full distant countdown");
    bb_update_notebook_respawns(1);
    bb_test_assert(!_book.taken,"Endless notebook respawns after 120 distant seconds");
    _g.debug.freeze_baldi=false;_g.anger_time=.5;_g.anger_rate=.01;_anger=_g.baldi_anger;
    bb_update_baldi(.6);
    bb_test_assert(abs(_g.baldi_anger-_anger-.01)<.0001 && abs(_g.anger_rate-.01025)<.0001,"Endless anger rate grows using source timing");
    _g.debug.god=false;_g.gameover=false;_g.notebooks=_high+1;bb_gameover();
    bb_test_assert(_g.new_high_score && global.high_books==_high+1,"Endless death records notebook high score");
    bb_test_assert(variable_struct_exists(global.PS,_g.gameover_image),"game-over selects an imported source failure image");
    audio_stop_all();global.high_books=_high;global.G=_original;bb_refresh_details();
}

function bb_test_crafters_gaze() {
    var _original=global.G,_walls=global.walls;
    global.G=variable_clone(_original);
    var _g=global.G,_craft=undefined;
    for (var _i=0;_i<array_length(_g.npcs);_i++) if (_g.npcs[_i].kind=="crafters") _craft=_g.npcs[_i];
    _g.state="play";_g.pause=false;_g.play_lock=0;_g.jump_height=0;
    _g.notebooks=7;_g.px=-22;_g.pz=-8;_g.yaw=0;
    _craft.x=-22;_craft.z=-24;_craft.live=true;_craft.visible=true;
    _craft.force_show=100;_craft.target_ready=false;_craft.angry=false;_craft.stare=0;
    _craft.source.speed=0;_craft.sees=true;
    bb_test_assert(bb_los(_g.px,_g.pz,_craft.x,_craft.z)
        && bb_crafters_under_crosshair(_craft),"Crafters gaze fixture is visible under the real camera reticle");
    var _rates=[30,60,144];
    for (var _ri=0;_ri<array_length(_rates);_ri++) {
        var _fps=_rates[_ri],_dt=1/_fps;
        for (var _sign=-1;_sign<=1;_sign+=2) {
            _g.yaw=degtorad(20*_sign);_craft.stare=0;_craft.angry=false;_craft.force_show=100;
            for (var _frame=0;_frame<_fps*2;_frame++) bb_ai_crafters(_craft,_dt);
            bb_test_assert(!_craft.angry && _craft.stare<=.000001
                && _g.px==-22 && _g.pz==-8,
                "Crafters off-reticle does not charge or teleport at "+string(_fps)+" FPS side="+string(_sign));
        }
        _g.yaw=0;
        for (var _frame=0;_frame<floor(_fps*.75);_frame++) bb_ai_crafters(_craft,_dt);
        bb_test_assert(!_craft.angry && _craft.stare>.7,"Crafters requires a full second of aimed gaze at "+string(_fps)+" FPS");
        _g.yaw=degtorad(20);
        for (var _frame=0;_frame<_fps;_frame++) bb_ai_crafters(_craft,_dt);
        bb_test_assert(!_craft.angry && _craft.stare<=.000001,"looking away drains Crafters gaze at "+string(_fps)+" FPS");
        _g.yaw=0;
        for (var _frame=0;_frame<=_fps && !_craft.angry;_frame++) bb_ai_crafters(_craft,_dt);
        bb_test_assert(_craft.angry,"one second of aimed gaze still triggers Crafters at "+string(_fps)+" FPS");
        _craft.angry=false;_craft.stare=0;
    }
    _g.yaw=0;
    bb_ai_crafters(_craft,.5,true);
    bb_test_assert(!bb_crafters_under_crosshair(_craft,true) && _craft.stare<=.000001,
        "looking back does not count Crafters in front of the player's body");
    _g.yaw=pi;
    bb_test_assert(bb_crafters_under_crosshair(_craft,true),"looking back can aim at Crafters behind the player's body");
    _g.play_lock=1;
    bb_test_assert(!bb_crafters_under_crosshair(_craft,true),"jump-rope space input does not rotate Crafters gaze");
    _g.play_lock=0;_g.yaw=0;
    _craft.visible=false;
    bb_test_assert(!bb_crafters_under_crosshair(_craft),"invisible Crafters cannot be targeted");
    _craft.visible=true;_craft.live=false;
    bb_test_assert(!bb_crafters_under_crosshair(_craft),"despawned Crafters cannot be targeted");
    _craft.live=true;_g.notebooks=6;bb_ai_crafters(_craft,1.1);
    bb_test_assert(!_craft.angry && _craft.stare<=.000001,"Crafters cannot charge before seven notebooks");
    _g.notebooks=7;
    // A newly closed obstruction must win even if the cached NPC sight is stale.
    global.walls=variable_clone(_walls);
    array_push(global.walls,{x0:-23,z0:-16.2,x1:-21,z1:-15.8,sight:true});
    bb_spatial_build();_craft.sees=true;bb_ai_crafters(_craft,1.1);
    bb_test_assert(!_craft.angry && _craft.stare<=.000001,
        "a wall blocks Crafters gaze immediately despite cached line of sight");
    global.walls=_walls;bb_spatial_build();
    // Once provoked, source chase remains active after the player turns away.
    _craft.angry=true;_craft.spd=0;_g.yaw=pi;bb_ai_crafters(_craft,0);
    bb_test_assert(_craft.angry && _craft.live,"provoked Crafters continues chasing after a turn away");
    _craft.x=_g.px;_craft.z=_g.pz;bb_ai_crafters(_craft,0);
    bb_test_assert(!_craft.live && !_craft.visible && _g.px==0 && _g.pz==-15
        && _g.baldi_x==0 && _g.baldi_z==-24,"provoked Crafters still teleports on contact and despawns");
    audio_stop_all();global.G=_original;bb_refresh_details();
}

function bb_test_principal_routes() {
    var _original=global.G;
    global.G=variable_clone(_original);
    var _g=global.G;
    _g.notebooks=7;_g.detention=0;
    for (var _i=0;_i<array_length(_g.doors);_i++) {
        _g.doors[_i].locked=false;_g.doors[_i].lock_cd=0;_g.doors[_i].open=true;
    }
    var _principal=undefined;
    for (var _i=0;_i<array_length(_g.npcs);_i++) if (_g.npcs[_i].kind=="principal") _principal=_g.npcs[_i];
    var _book=_g.notebooks_list[6];
    bb_debug_focus(_book.x,_book.z);
    var _spawn=[_g.px,_g.pz];
    show_debug_message("BB_TEST_NOTEBOOK7: "+string([_book.x,_book.z])+" teleport="+string(_spawn));
    for (var _ti=0;_ti<array_length(global.E.targets);_ti++) {
        var _target=global.E.targets[_ti];
        _principal.x=_spawn[0];_principal.z=_spawn[1];
        var _last=[];
        var _goal=bb_grid_start(_target[0],_target[2]);
        var _tx=global.path_grid.xs[_goal],_tz=global.path_grid.zs[_goal];
        for (var _step=0;_step<2400;_step++) {
            bb_ai_go(_principal,_target[0],_target[2],_principal.source.speed,1/30);
            if (_step>=2394) array_push(_last,[_principal.x,_principal.z]);
            if (bb_dist2(_principal.x,_principal.z,_tx,_tz)<.26) break;
        }
        bb_test_assert(bb_dist2(_principal.x,_principal.z,_tx,_tz)<.26,
            "principal leaves Notebook7 for patrol target "+string(_ti)+" target="+string(_target)+" last="+string(_last));
    }
    var _rates=[30,60,144];
    for (var _ri=0;_ri<array_length(_rates);_ri++) {
        random_set_seed(143);
        _principal.x=_spawn[0];_principal.z=_spawn[1];
        _principal.target_x=14;_principal.target_z=-60;_principal.target_ready=true;
        _principal.stuck=0;_principal.wander_cool=0;_principal.cool=0;
        _principal.sees=false;_g.guilt=0;_g.prin_chase=false;
        for (var _step=0;_step<_rates[_ri]*12;_step++) bb_ai_principal(_principal,1/_rates[_ri]);
        bb_test_assert((_principal.target_x!=14 || _principal.target_z!=-60)
            && bb_dist2(_principal.x,_principal.z,14,-60)>4,
            "principal resumes patrol after Notebook7 chair endpoint "+string(_rates[_ri])+"fps");
    }
    _principal.x=14;_principal.z=-60.5;_principal.live=true;
    _principal.target_x=14;_principal.target_z=-60;_principal.target_ready=true;_principal.stuck=0;
    _g.sprays=[{x:14,z:-60.5,dx:0,dz:-1,life:30}];
    for (var _step=0;_step<15;_step++) bb_update_sprays(1/60);
    bb_test_assert(_principal.sprayed && _principal.z<-60.6,"BSODA displaces principal from Notebook7 chair endpoint");
    _g.sprays=[];bb_update_sprays(1/60);
    for (var _step=0;_step<720;_step++) bb_ai_principal(_principal,1/60);
    bb_test_assert((_principal.target_x!=14 || _principal.target_z!=-60)
        && bb_dist2(_principal.x,_principal.z,14,-60)>4,
        "principal does not remain at Notebook7 chair endpoint after BSODA wears off");
    global.G=_original;
}

function bb_test_detention() {
    var _original=global.G;
    global.G=variable_clone(_original);
    var _g=global.G;
    _g.notebooks=7;_g.debug.no_rules=false;_g.debug.god=true;
    _g.debug.freeze_npcs=true;_g.debug.freeze_baldi=true;
    _g.state="play";_g.pause=false;_g.det_n=0;_g.gameover=false;_g.win=false;
    var _principal=undefined;
    for (var _i=0;_i<array_length(_g.npcs);_i++) if (_g.npcs[_i].kind=="principal") _principal=_g.npcs[_i];
    var _door=_g.doors[bb_office_door()];
    bb_give_detention(_principal);
    bb_test_assert(_g.detention==15 && _g.px==1 && _g.pz==-31
        && _principal.x==1 && _principal.z==-33,"detention uses source player/principal warp coordinates");
    for (var _i=0;_i<299;_i++) bb_ai_principal(_principal,1/60);
    bb_test_assert(_principal.x==1 && _principal.z==-33,"principal pauses for source five-second cooldown");
    _principal.target_x=6;_principal.target_z=-32;_principal.target_ready=true;
    _principal.wander_cool=0;_principal.sees=false;_g.guilt=0;
    var _door_stayed_closed=true;
    for (var _i=0;_i<240;_i++) {
        bb_ai_principal(_principal,1/60);
        _door_stayed_closed=_door_stayed_closed && !_door.open && _door.locked;
        if (!bb_region_contains(global.E.office,_principal.x,_principal.z)) break;
    }
    bb_test_assert(!bb_region_contains(global.E.office,_principal.x,_principal.z)
        && _g.detention>0,"principal leaves while player is still in detention");
    bb_test_assert(_door_stayed_closed && bb_blocked_world(_door.cx,_door.cz,_g.radius,true),
        "principal leaves without opening blue door or releasing player collision");
    var _other={kind:"playtime",x:4,z:-31.5,stuck:0};
    for (var _i=0;_i<120;_i++) bb_ai_go(_other,6,-31.5,4,1/60);
    bb_test_assert(_other.x<5 && !_door.open,"office exit permission does not leak to other NPC paths");
    var _office_index=bb_office_door();
    bb_grid_step(4,-31.5,6,-31.5,.3,_office_index);
    bb_grid_step(4,-31.5,6,-31.5,.3);
    var _cached_searches=global.path_grid.searches;
    bb_grid_step(4,-31.5,6,-31.5,.3,_office_index);
    bb_grid_step(4,-31.5,6,-31.5,.3);
    // Unreachable searches need not be cached, but the principal's settled
    // route must survive another actor's different locked-door permission.
    bb_test_assert(global.path_grid.searches<=_cached_searches+1,
        "principal office permission does not flush other actor route caches");
    _g.px=4;_g.pz=-31.5;_g.yaw=-pi/2;_g.inv=[3,-1,-1];_g.inv_sel=0;
    var _time=_g.detention,_lock=_door.lock_cd;
    bb_test_assert(bb_use_item() && _g.inv[0]==-1 && _door.open && !_door.locked,
        "office key unlocks and opens the targeted door");
    bb_test_assert(_g.detention==_time && _door.lock_cd==_lock,
        "office key preserves detention and source lockTime");
    _door.open=false;
    bb_test_assert(bb_door_try_open(_door,true),"key-unlocked door can reopen while lockTime remains positive");
    _g.inv[0]=3;
    bb_test_assert(!bb_use_item() && _g.inv[0]==3,"key is not consumed again on an unlocked door");
    var _escape=bb_move_slide(4,-31.5,2,0,_g.radius,true);
    _g.px=_escape[0];_g.pz=_escape[1];
    bb_game_update(1/60);
    bb_test_assert(_g.detention>0 && _g.guilt>0 && _g.guilt_type=="escape",
        "leaving with office key still triggers no escaping detention");
    bb_update_doors(100);
    bb_test_assert(!_door.locked && _door.lock_cd==0,"office lock expires naturally after key use");
    audio_stop_all();global.G=_original;
}

function bb_test_ai_profile() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    random_set_seed(143);
    _g.debug.god = true; _g.debug.no_rules = true;
    _g.px = 0; _g.pz = -12; _g.notebooks = 7;
    bb_activate_spoop();
    var _start = get_timer(), _peak = 0;
    for (var _i = 0; _i < 120; _i++) {
        var _tick = get_timer();
        bb_update_baldi(1/60); bb_update_npcs(1/60);
        _peak = max(_peak, get_timer()-_tick);
    }
    show_debug_message("BB_PROFILE_AI: 120 frames avg_us=" + string((get_timer()-_start)/120) + " peak_us=" + string(_peak));
    audio_stop_all(); global.G = _original; bb_refresh_details();
}

function bb_test_stationary_navigation() {
    // Arrival and a missing next step both produce a zero-length direction.
    var _offsets = [0, 0.000001];
    for (var _i = 0; _i < array_length(_offsets); _i++) {
        var _ok = false;
        try {
            var _pos = bb_nav_advance(0, -2, _offsets[_i], -2, 0.25, 0.28, true);
            _ok = !is_nan(_pos[0]) && !is_nan(_pos[1]) && abs(_pos[0]) <= 0.00001 && _pos[1] == -2;
        } catch (_error) {
            show_debug_message("BB_TEST_NAV_ERROR: " + _error.message);
        }
        bb_test_assert(_ok, "stationary navigation remains finite at offset " + string(_offsets[_i]));
    }
    var _pos = bb_nav_advance(0, -2, 0, -4, 0.25, 0.28, true);
    bb_test_assert(_pos[0] == 0 && abs(_pos[1]+2.25) < 0.0001, "navigation resumes normally toward a new target after arrival");
    var _center_checked = 0, _keys = ds_map_keys_to_array(global.nav_n);
    for (var _i=0; _i<array_length(_keys) && _center_checked<16; _i++) {
        var _parts = string_split(_keys[_i], ","), _cx0 = real(_parts[0]), _cz0 = real(_parts[1]);
        var _corridor = bb_nav_corridor(_cx0, _cz0), _old_x = _cx0, _old_z = _cz0;
        if (_corridor[0] == 1) _old_x += .3; else if (_corridor[0] == 2) _old_z += .3; else continue;
        var _near_door=false;
        for (var _di=0;_di<array_length(global.G.doors);_di++) {
            if (bb_dist2(_cx0,_cz0,global.G.doors[_di].cx,global.G.doors[_di].cz)<4) {_near_door=true;break;}
        }
        if (_near_door || bb_blocked_world(_old_x, _old_z, .28, true)
            || bb_walls_segment(_old_x,_old_z,_cx0,_cz0,.28)) continue;
        var _neighbors=ds_map_find_value(global.nav_n,_keys[_i]);
        if (array_length(_neighbors)==0) continue;
        var _target_parts=string_split(_neighbors[0],",");
        var _target_x=real(_target_parts[0]),_target_z=real(_target_parts[1]);
        var _weighted_start=bb_grid_nearest(_old_x,_old_z);
        var _weighted_wp=bb_grid_step(_old_x,_old_z,_target_x,_target_z);
        var _center = bb_nav_advance(_old_x,_old_z,_target_x,_target_z,.3,.28,true);
        var _before = (_corridor[0] == 1) ? abs(_old_x-_cx0) : abs(_old_z-_cz0);
        var _after = (_corridor[0] == 1) ? abs(_center[0]-_cx0) : abs(_center[1]-_cz0);
        bb_test_assert(_after<.08 && _after<_before
            && bb_dist2(_old_x,_old_z,_center[0],_center[1])>0,
            "weighted NPC route enters corridor center "+string(_center_checked)
            +" axis="+string(_corridor[0])+" from="+string([_old_x,_old_z])
            +" grid="+string([global.path_grid.xs[_weighted_start],global.path_grid.zs[_weighted_start]])
            +" waypoint="+string(_weighted_wp)+" target="+string([_target_x,_target_z])
            +" result="+string(_center));
        var _slap=bb_nav_advance(_old_x,_old_z,
            _target_x,_target_z,3,.28,true);
        var _slap_offset=(_corridor[0]==1)?abs(_slap[0]-_cx0):abs(_slap[1]-_cz0);
        bb_test_assert(_slap_offset < .01 && !bb_blocked_world(_slap[0],_slap[1],.28,true),
            "weighted Baldi route stays on corridor center "+string(_center_checked));
        _center_checked+=1;
    }
    bb_test_assert(_center_checked>=12, "weighted centering covers representative school corridors");
    // Locker.png occupies x=5.0..5.4 along this source hallway. A westbound
    // spray may displace Baldi up to its collision edge, then route recovery
    // must pull him back to the x=6 road center without entering the lockers.
    var _locker_push=bb_move_slide(6,-46.4,-.8,0,.28,true);
    bb_test_assert(_locker_push[0]<6 && _locker_push[0]>5.6
        && !bb_blocked_world(_locker_push[0],_locker_push[1],.28,true),
        "BSODA displacement stops outside the Locker.png collision strip");
    var _locker_recover=bb_nav_advance(_locker_push[0],_locker_push[1],6,-44,3,.28,true);
    bb_test_assert(abs(_locker_recover[0]-6)<.01
        && !bb_blocked_world(_locker_recover[0],_locker_recover[1],.28,true),
        "AI route returns from Locker.png to the road center at full movement speed");
    var _playtime=undefined;
    for (var _i=0;_i<array_length(global.G.npcs);_i++) {
        if (global.G.npcs[_i].kind=="playtime") {_playtime=global.G.npcs[_i];break;}
    }
    var _play_spawn_x=_playtime.source.spawn[0],_play_spawn_z=_playtime.source.spawn[1];
    bb_test_assert(bb_blocked_world(_play_spawn_x,_play_spawn_z,.3,true)
        && !bb_blocked_world(_playtime.x,_playtime.z,.3,true),
        "Playtime source spawn is recovered from the long-corridor wall margin");
    _playtime.x=_play_spawn_x;_playtime.z=_play_spawn_z;
    for (var _step=0;_step<120;_step++) bb_ai_go(_playtime,-22,-48,4,1/60);
    bb_test_assert(!bb_blocked_world(_playtime.x,_playtime.z,.3,true)
        && bb_dist2(_playtime.x,_playtime.z,_play_spawn_x,_play_spawn_z)>16,
        "Playtime escapes the authored wall overlap and travels down the long corridor");
    // Classroom chairs are dense enough that a continuous position can round
    // to a grid node on the chair's far side. Verify that AI selects a locally
    // reachable start node and routes around representative source chairs.
    var _chairs_checked=0;
    for (var _ci=0;_ci<array_length(global.E.colliders) && _chairs_checked<8;_ci++) {
        var _chair=global.E.colliders[_ci];
        if (abs(_chair[1]-.07)>.02 || abs(_chair[4]-.73)>.02
            || abs((_chair[3]-_chair[0])-.6)>.03 || abs((_chair[5]-_chair[2])-.6)>.03) continue;
        var _cx=(_chair[0]+_chair[3])*.5,_cz=(_chair[2]+_chair[5])*.5;
        var _sx=0,_sz=0,_tx=0,_tz=0,_pair=false;
        for (var _axis=0;_axis<2 && !_pair;_axis++) {
            for (var _gap=.35;_gap<=1.15;_gap+=.2) {
                if (_axis==0) {
                    _sx=_chair[0]-_gap;_sz=_cz;_tx=_chair[3]+_gap;_tz=_cz;
                } else {
                    _sx=_cx;_sz=_chair[2]-_gap;_tx=_cx;_tz=_chair[5]+_gap;
                }
                _pair=bb_on_floor(_sx,_sz) && bb_on_floor(_tx,_tz)
                    && !bb_blocked_world(_sx,_sz,.3,true) && !bb_blocked_world(_tx,_tz,.3,true);
                if (_pair) break;
            }
        }
        if (!_pair) continue;
        var _x=_sx,_z=_sz;
        for (var _step=0;_step<1200;_step++) {
            var _around=bb_nav_advance(_x,_z,_tx,_tz,.05,.3,true);
            _x=_around[0];_z=_around[1];
            if (bb_dist2(_x,_z,_tx,_tz)<.04) break;
        }
        bb_test_assert(bb_dist2(_x,_z,_tx,_tz)<.04 && !bb_blocked_world(_x,_z,.3,true),
            "NPC independently routes around classroom chair "+string(_chairs_checked)
            +" from="+string([_sx,_sz])+" to="+string([_tx,_tz])+" result="+string([_x,_z]));
        _chairs_checked+=1;
    }
    bb_test_assert(_chairs_checked>=6,
        "chair navigation covers representative classroom furniture count="+string(_chairs_checked));
    var _door_index = -1;
    for (var _i=0; _i<array_length(global.G.doors); _i++) {
        if (global.G.doors[_i].kind == "class") { _door_index = _i; break; }
    }
    var _door = global.G.doors[_door_index], _box = bb_door_box(_door);
    var _cx = (_box[0]+_box[2])*.5, _cz = (_box[1]+_box[3])*.5;
    var _nx = ((_box[2]-_box[0]) < (_box[3]-_box[1])) ? 1 : 0, _nz = 1-_nx;
    _door.open = false; _door.locked = false; _door.lock_cd = 0;
    bb_npc_open_path_doors(_cx-_nx, _cz-_nz, _cx+_nx, _cz+_nz, .3);
    bb_test_assert(_door.open, "NPC path proactively opens an unlocked blue or brown door");
    _door.open = false; _door.locked = true;
    bb_npc_open_path_doors(_cx-_nx, _cz-_nz, _cx+_nx, _cz+_nz, .3);
    bb_test_assert(!_door.open, "NPC path respects a genuinely locked door");
    _door.locked = false;
    // IEEE values from a buffer exercise invalid movement without dividing by zero.
    var _buffer = buffer_create(8, buffer_fixed, 1);
    buffer_poke(_buffer, 0, buffer_u32, 0);
    var _high_words = [2146959360, 2146435072]; // quiet NaN and positive infinity
    for (var _i = 0; _i < array_length(_high_words); _i++) {
        buffer_poke(_buffer, 4, buffer_u32, _high_words[_i]);
        var _bad = buffer_peek(_buffer, 0, buffer_f64);
        var _pos = bb_move_slide(0, -2, _bad, 0, 0.28, true);
        bb_test_assert(_pos[0] == 0 && _pos[1] == -2, "invalid movement keeps last valid position " + string(_i));
    }
    buffer_delete(_buffer);
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    _g.state = "play"; _g.debug.god = true; _g.debug.freeze_baldi = false;
    _g.px = 0; _g.pz = -24; _g.baldi_x = 0; _g.baldi_z = -24;
    _g.baldi_active = true; _g.baldi_sprayed = false; _g.baldi_move = 0.2; _g.baldi_cd = 1;
    var _ok = false;
    try {
        bb_update_baldi(1/60);
        _ok = !is_nan(_g.baldi_x) && !is_nan(_g.baldi_z) && _g.baldi_x == 0 && _g.baldi_z == -24;
    } catch (_error) {
        show_debug_message("BB_TEST_NAV_ERROR: " + _error.message);
    }
    bb_test_assert(_ok, "Baldi can arrive at his hearing target without NaN");
    _g.baldi_move = 0; _g.baldi_cd = 0; _g.baldi_cool = 0;
    _g.baldi_prev_x = _g.baldi_x; _g.baldi_prev_z = _g.baldi_z;
    _g.hear_x = _g.baldi_x; _g.hear_z = _g.baldi_z;
    var _hidden_player = false, _floor_keys = ds_map_keys_to_array(global.floors);
    for (var _i=0; _i<array_length(_floor_keys); _i++) {
        var _parts=string_split(_floor_keys[_i],","), _hx=real(_parts[0]), _hz=real(_parts[1]);
        if (bb_dist2(_hx,_hz,_g.baldi_x,_g.baldi_z)>100 && !bb_los(_g.baldi_x,_g.baldi_z,_hx,_hz)) {
            _g.px=_hx; _g.pz=_hz; _hidden_player=true; break;
        }
    }
    random_set_seed(143);
    bb_update_baldi(1/60);
    bb_test_assert(_hidden_player && (_g.hear_x != _g.baldi_x || _g.hear_z != _g.baldi_z),
        "Baldi resumes wandering when a stationary cooldown lands exactly on zero");
    global.G = _original;
}

function bb_test_yctp_state() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    audio_stop_all();
    _g.state = "play"; _g.spoop_mode = false; _g.notebooks = 0;
    _g.audio_log = [];
    bb_collect_notebook(0);
    bb_audio_update(0.01); bb_yctp_face_update(0.05);
    bb_test_assert(_g.state == "yctp" && _g.notebooks == 1 && _g.notebooks_list[0].taken, "notebook click opens first pad");
    bb_test_assert(array_length(_g.audio_log) == 2 && _g.audio_log[0].clip == global.S.learnMusic
        && _g.audio_log[1].clip == global.S.bal_intro, "notebook entry plays only learn music and intro; no bell");
    bb_test_assert(_g.yctp_face_visible && _g.yctp_face_state == "talk", "Baldi face talks with math voice");
    var _frame = bb_yctp_face_texture();
    bb_yctp_face_update(0.1);
    bb_test_assert(bb_yctp_face_texture() != _frame, "talking face advances through source frames");
    bb_voice_clear("math"); bb_yctp_face_update(0.01);
    bb_test_assert(_g.yctp_face_state == "idle", "face rests when voice stops");
    _g.yctp_input = "99999";
    var _music = _g.yctp_music;
    var _transition_start=get_timer();
    bb_yctp_submit();
    show_debug_message("BB_PROFILE_FIRST_WRONG_US: "+string(get_timer()-_transition_start));
    bb_test_assert(_g.spoop_mode && _g.yctp_face_visible && _g.yctp_face_state == "frown", "first wrong answer starts visible frown");
    bb_test_assert(!audio_is_playing(_music), "first wrong answer stops learning music");
    bb_yctp_face_update(0.2); _frame = bb_yctp_face_texture();
    bb_yctp_face_update(0.2);
    bb_test_assert(bb_yctp_face_texture() != _frame, "frown animates after wrong answer");
    _g.audio_log = [];
    _g.yctp_input = string(_g.yctp_ans); bb_yctp_submit(); bb_audio_update(0.01);
    bb_test_assert(array_length(_g.audio_log) == 0, "correct answer after failure stays silent");
    bb_yctp_close();
    bb_test_assert(_g.move_latched,"leaving the learning scene latches held movement keys");
    bb_test_assert(!bb_movement_ready(true) && _g.move_latched,
        "a held movement key remains blocked after a scene switch");
    bb_test_assert(!bb_movement_ready(false) && !_g.move_latched,
        "releasing all movement keys clears the scene-switch latch without moving");
    bb_test_assert(bb_movement_ready(true),"a fresh movement-key press works after release");
    var _alarm = bb_sound_play(snd_alarm);
    _g.audio_log = [];
    bb_collect_notebook(1); bb_audio_update(0.01); bb_yctp_face_update(0.01);
    bb_test_assert(!_g.yctp_face_visible && array_length(_g.audio_log) == 0, "next notebook after failure has no Baldi face or math audio");
    bb_test_assert(audio_is_paused(_alarm), "world alarm cannot leak into learning screen");
    // Exercise both enqueue and playback guards, including a stale queue.
    bb_voice_queue("math", [global.S.bal_intro]);
    bb_test_assert(array_length(_g.voices.math.queue) == 0, "spoop mode rejects new math speech");
    _g.voices.math.queue = [global.S.bal_howto]; _g.voices.math.head = 0;
    bb_audio_update(0.01);
    bb_test_assert(array_length(_g.audio_log) == 0 && _g.voices.math.handle == -1, "spoop mode discards stale voice before playback");
    bb_debug_open(); bb_debug_close();
    bb_test_assert(audio_is_paused(_alarm) && _g.voices.math.handle == -1, "closing cheats cannot resume world alarm or stale Baldi voice in pad");
    _g.yctp_input = string(_g.yctp_ans); bb_yctp_submit(); bb_audio_update(0.01);
    bb_test_assert(array_length(_g.audio_log) == 0, "later notebook correct answer stays silent");
    bb_yctp_close();
    bb_test_assert(!audio_is_paused(_alarm), "leaving pad resumes existing world alarm");
    audio_stop_all();
    global.G = _original;
    bb_refresh_details();
}

function bb_test_debug_menu() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    audio_stop_all();
    bb_test_assert(!_g.debug.open && !_g.debug.god && !_g.debug.noclip && !_g.debug.items, "cheats default off");
    var _tone = bb_sound_play(snd_antihearing);
    bb_debug_open();
    var _time = _g.nb_t, _px = _g.px;
    bb_game_update(0.1);
    bb_test_assert(_g.debug.open && _g.nb_t == _time && _g.px == _px, "open cheat menu blocks gameplay update");
    bb_test_assert(audio_is_paused(_tone), "cheat menu pauses audio");
    bb_debug_close();
    bb_test_assert(!audio_is_paused(_tone) && !_g.pause, "closing cheat menu resumes play audio");
    _g.pause = true; audio_pause_all();
    bb_debug_open(); bb_debug_close();
    bb_test_assert(_g.pause && audio_is_paused(_tone), "cheat menu preserves existing pause");
    _g.pause = false; audio_resume_all();
    _g.notebooks = 1; bb_yctp_open(); bb_audio_update(0.01);
    var _voice = _g.voices.math.handle;
    bb_debug_open(); bb_debug_close();
    bb_test_assert(_g.state == "yctp" && !audio_is_paused(_voice) && audio_is_paused(_tone), "pad voice resumes while world audio stays paused");
    bb_debug_open(); bb_debug_action("spawn");
    bb_test_assert(_g.debug.open && _g.state == "play", "teleport leaves pad but keeps cheat menu modal");
    bb_debug_close();
    bb_debug_action("toggle", "god"); bb_gameover();
    bb_test_assert(!_g.gameover, "god mode prevents Baldi game-over");
    bb_debug_action("toggle", "god"); bb_gameover();
    bb_test_assert(_g.gameover, "disabling god mode restores game-over");
    bb_debug_open(); bb_debug_action("spawn"); bb_debug_close();
    bb_test_assert(!_g.gameover && !_g.win && !bb_blocked_world(_g.px, _g.pz, _g.radius, true), "revive returns to safe spawn");
    _g.px = -0.5; _g.pz = -4.5;
    var _blocked = bb_debug_player_move(-1, 0);
    bb_debug_action("toggle", "noclip");
    var _free = bb_debug_player_move(-1, 0);
    bb_test_assert(_blocked[0] > -1 && _free[0] == -1.5, "noclip crosses wall only when enabled");
    _g.px = -1; _g.pz = -4.5;
    bb_debug_action("toggle", "noclip");
    bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true), "disabling noclip resolves wall overlap");
    bb_debug_action("actor", 0);
    bb_debug_action("actor_here");
    bb_test_assert(_g.npcs[0].live && _g.npcs[0].visible && _g.npcs[0].x == _g.px && _g.npcs[0].z == _g.pz,
        "cheat menu brings a selected NPC to the player's arbitrary position");
    bb_debug_action("actor_ahead");
    bb_test_assert(bb_dist2(_g.npcs[0].x, _g.npcs[0].z, _g.px, _g.pz) >= 1,
        "cheat menu places a selected NPC ahead on clear ground");
    bb_debug_action("actor_go");
    bb_test_assert(bb_dist2(_g.px, _g.pz, _g.npcs[0].x, _g.npcs[0].z) < 4,
        "cheat menu teleports the player to a selected NPC");
    bb_debug_action("slot", 1);
    for (var _i = 1; _i <= 10; _i++) {
        bb_debug_action("item", _i);
        bb_test_assert(_g.inv[1] == _i, "give item into chosen slot " + string(_i));
    }
    bb_debug_action("slot", 0); bb_debug_action("item", 4);
    bb_debug_action("toggle", "items"); bb_use_item();
    bb_test_assert(_g.inv[0] == 4 && array_length(_g.sprays) > 0, "infinite item use retains BSODA");
    bb_debug_action("toggle", "items"); bb_use_item();
    bb_test_assert(_g.inv[0] == -1, "normal consumption restored");
    bb_debug_action("books", 7);
    bb_test_assert(_g.exit_open && _g.notebooks == 7 && _g.notebooks_list[6].taken, "seven-book cheat enables exits and hides books");
    bb_debug_action("books", 0);
    bb_test_assert(!_g.exit_open && !_g.notebooks_list[0].taken && _g.exit_got == 0, "book reset restores notebooks and exit state");
    bb_debug_action("doors_open");
    var _unlocked = true;
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        if (_g.doors[_i].locked || !_g.doors[_i].open) _unlocked = false;
    }
    bb_test_assert(_unlocked && _g.debug.free_doors, "all doors open including initial notebook gates");
    bb_debug_action("toggle", "free_doors");
    var _gated = false;
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        if (_g.doors[_i].kind == "swing" && _g.doors[_i].locked) _gated = true;
    }
    bb_test_assert(_gated, "disabling free doors restores notebook gates");
    bb_debug_action("chase");
    bb_debug_action("toggle", "freeze_baldi");
    var _cd = _g.baldi_cd;
    bb_update_baldi(0.2);
    bb_test_assert(_g.baldi_cd == _cd, "paused Baldi AI keeps its timer");
    bb_debug_action("toggle", "freeze_npcs");
    var _wait = _g.npcs[0].wait;
    bb_update_npcs(0.2);
    bb_test_assert(_g.npcs[0].wait == _wait, "other NPC AI pauses");
    _g.detention = 30; _g.prin_chase = true;
    bb_debug_action("toggle", "no_rules");
    bb_test_assert(_g.detention == 0 && !_g.prin_chase, "no-punishment clears detention");
    bb_debug_open(); bb_debug_action("math");
    _g.yctp_corrupt = true;
    bb_debug_action("math_finish");
    bb_test_assert(_g.state == "play" && _g.yctp_marks[0] == 1 && _g.yctp_marks[2] == 1 && _g.debug.open, "finish-pad cheat accepts impossible questions and preserves overlay");
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        bb_debug_action("door", _i);
        bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true), "safe teleport to door " + string(_i));
    }
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        bb_debug_action("notebook", _i);
        var _n = _g.notebooks_list[_i];
        bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true) && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 4, "notebook teleport arrives within pickup range " + string(_i));
    }
    for (var _tab = 0; _tab < 4; _tab++) {
        bb_debug_action("tab", _tab);
        var _pages = _g.debug.pages;
        for (var _page = 0; _page < _pages; _page++) {
            _g.debug.page = _page; bb_debug_layout();
            var _ok = true;
            for (var _i = 0; _i < array_length(_g.debug.buttons); _i++) {
                var _b = _g.debug.buttons[_i];
                if (_b.x1 < 0 || _b.y1 < 0 || _b.x2 > 640 || _b.y2 > 430) _ok = false;
            }
            bb_test_assert(_ok, "cheat page stays inside viewport " + string(_tab) + "/" + string(_page));
        }
    }
    bb_debug_close();
    audio_stop_all();
    global.G = _original;
    bb_refresh_details();
}

function bb_test_end_states() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    audio_stop_all();

    _g.mode = "story"; _g.state = "yctp"; _g.spoop_mode = true;
    _g.failed_nbs = 6; _g.yctp_wrong = 3; _g.yctp_q = 3;
    bb_yctp_make();
    bb_test_assert(_g.failed_nbs == 7 && _g.yctp_end, "three wrong answers count one fully failed notebook");

    bb_secret_begin();
    var _secret = global.P.details.secret;
    bb_test_assert(_g.state == "secret" && _g.px == _secret.player[0] && _g.pz == _secret.player[1],
        "Secret spawn uses the source position");
    bb_test_assert(_g.move_latched,"entering the Secret scene latches held movement keys");
    bb_test_assert(abs(_g.yaw-pi) < .001,
        "Secret spawn faces secretwall");
    bb_test_assert(global.map.scene == "Secret" && global.E.source_scene == "Secret"
        && ds_map_size(global.floors) == 28 && array_length(_g.doors) == 1,
        "seven failed notebooks rebuild the complete Secret room");
    bb_test_assert(_g.doors[0].material == "BaldiDoor"
        && variable_struct_exists(global.map_textures, global.map.materials.BaldiDoor.file),
        "Secret connecting door uses its source green texture");
    var _secret_door = _g.doors[0];
    bb_door_try_open(_secret_door, true);
    bb_test_assert(_secret_door.open && !bb_blocked_world(_secret_door.cx,_secret_door.cz,.28,true),
        "Secret connecting door opens and permits access to the room");
    _secret_door.open = false;
    bb_test_assert(array_length(global.E.meshes) == 2 && array_length(global.E.billboards) == 1
        && variable_struct_exists(global.PS, "secret_filename2"),
        "Secret room includes its furniture and source actors");
    _g.px = _secret.filename2.x; _g.pz = _secret.filename2.z;
    bb_secret_update(.01);
    bb_test_assert(_g.secret_played && _g.secret_sound != -1 && audio_is_playing(_g.secret_sound),
        "approaching filename2 starts the source recording");
    audio_stop_sound(_g.secret_sound); bb_secret_update(.01);
    bb_test_assert(_g.end_requested, "Secret recording completion requests application exit");

    global.G = variable_clone(_original); _g = global.G;
    bb_world_load("school_map.json", global.P.environment_file);
    audio_stop_all(); bb_win_game();
    audio_stop_sound(_g.win_sound);
    bb_win_update(.99);
    bb_test_assert(!_g.end_requested, "victory waits one second after its sound");
    bb_win_update(.01);
    bb_test_assert(_g.end_requested, "victory exits one second after its sound completes");

    global.G = variable_clone(_original); _g = global.G;
    audio_stop_all(); _g.debug.god = false; bb_gameover();
    _g.gameover_rare = false; _g.gameover_image = "gameover_0";
    bb_gameover_update(.9);
    bb_test_assert(_g.over_t < 1 && !_g.end_requested, "Baldi catch keeps the one-second far-clip transition");
    bb_gameover_update(.1);
    bb_test_assert(_g.over_t >= 1 && variable_struct_exists(global.PS, _g.gameover_image),
        "catch transition reveals a source 2048px game-over image in the 400px frame");

    audio_stop_all(); global.G = _original; bb_refresh_details();
}

function bb_test_scene_details() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    audio_stop_all();
    _g.state = "play"; _g.spoop_mode = false; _g.win = false; _g.gameover = false;
    _g.px = 0; _g.pz = -2;
    bb_debug_notebooks(0);
    var _entrance_start=get_timer();
    bb_activate_spoop();
    show_debug_message("BB_PROFILE_FIRST_ENTRANCE_US: "+string(get_timer()-_entrance_start));
    for (var _i = 0; _i < array_length(_g.exits); _i++) {
        var _e = _g.exits[_i], _b = _e.source.wall_bounds;
        bb_test_assert(_e.down && bb_blocked_world((_b[0]+_b[3])*0.5, (_b[2]+_b[5])*0.5, .28, true), "wrong-answer wall blocks exit " + _e.name);
    }
    bb_debug_notebooks(7);
    bb_voice_replace("tutor", [global.S.aud_AllNotebooks]); bb_audio_update(.01);
    var _all_notebooks_voice = _g.voices.tutor.handle;
    bb_finale_audio(1);
    bb_test_assert(_g.voices.tutor.handle == _all_notebooks_voice && audio_is_playing(_all_notebooks_voice),
        "first exit machine audio overlaps the full AllNotebooks speech");
    for (var _i = 0; _i < array_length(_g.exits); _i++) {
        var _e = _g.exits[_i], _b = _e.source.wall_bounds;
        bb_test_assert(!_e.down && !bb_blocked_world((_b[0]+_b[3])*0.5, (_b[2]+_b[5])*0.5, .28, true), "seven books restore exit " + _e.name);
    }
    // Test all approach directions, well before reaching the physical exit plane.
    for (var _i = 0; _i < 3; _i++) {
        var _e = _g.exits[_i], _s = _e.source;
        var _b = _s.wall_bounds, _cx = (_b[0]+_b[3])*.5, _cz = (_b[2]+_b[5])*.5;
        var _dx = sign(_cx-_s.origin[0]), _dz = sign(_cz-_s.origin[2]);
        _g.px = _s.origin[0]-_dx*.2; _g.pz = _s.origin[2]-_dz*.2;
        var _previous = _g.finale_sound;
        var _exit_start=get_timer();
        bb_check_exits();
        show_debug_message("BB_PROFILE_EXIT_"+string(_i)+"_US: "+string(get_timer()-_exit_start));
        bb_test_assert(_e.used && _e.down && _g.exit_got == _i+1 && !_g.win, "near trigger closes unique exit " + string(_i));
        bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true), "early closure leaves player on clear ground " + string(_i));
        if (_previous != -1) bb_test_assert(!audio_is_playing(_previous), "finale stage stops preceding loop " + string(_i));
        bb_check_exits();
        bb_test_assert(_g.exit_got == _i+1, "same exit cannot count twice");
    }
    var _rev = _g.finale_sound;
    bb_audio_update(.01);
    bb_test_assert(!_g.finale_loop && _g.finale_sound == _rev, "third exit cannot start loop over rev intro");
    audio_stop_sound(_rev); _g.finale_remaining = 0;
    bb_audio_update(.01);
    bb_test_assert(_g.finale_loop && _g.finale_sound != _rev, "third exit loop follows completed intro");
    var _last = _g.exits[3], _f = _last.source.finish;
    _g.px = _last.source.origin[0]; _g.pz = _last.source.origin[2];
    bb_check_exits();
    bb_test_assert(!_g.win && !_last.down, "last exit stays open and does not win at near trigger");
    bb_voice_queue("principal", [global.S.audDetention]);
    var _noise = bb_sound_play(snd_alarm);
    _g.px = (_f[0]+_f[3])*.5; _g.pz = (_f[2]+_f[5])*.5;
    bb_check_exits();
    var _win_handle = _g.win_sound;
    bb_test_assert(_g.win && _win_handle != -1 && !audio_is_playing(_noise), "finish stops world audio and starts Results clip");
    var _plays = array_length(_g.audio_log);
    bb_audio_update(1); bb_win_game();
    bb_test_assert(array_length(_g.audio_log) == _plays && _g.win_sound == _win_handle && _g.finale_sound == -1,
        "post-win update cannot restart finale or queued voices");
    bb_debug_open(); bb_debug_close();
    bb_test_assert(!audio_is_paused(_win_handle), "cheat overlay resumes victory clip");
    _g.win = false; bb_debug_notebooks(7);
    var _e = _g.exits[0], _s = _e.source, _b = _s.wall_bounds;
    var _cx = (_b[0]+_b[3])*.5, _cz = (_b[2]+_b[5])*.5;
    var _dx = sign(_cx-_s.origin[0]), _dz = sign(_cz-_s.origin[2]);
    _g.px = _cx+_dx*.2; _g.pz = _cz+_dz*.2;
    bb_check_exits(_s.origin[0]-_dx*2, _s.origin[2]-_dz*2);
    bb_test_assert(_e.down && !bb_blocked_world(_g.px, _g.pz, _g.radius, true), "fast approach is swept and ejected before wall closes");
    _g.inv = [10, -1, -1]; _g.inv_sel = 0;
    bb_use_item();
    bb_test_assert(_g.boots == 15 && _g.boot_anim == 0, "boots start protection and entry animation together");
    bb_update_item_effects(1);
    var _r = bb_boots_rect(_g.boot_anim);
    bb_test_assert(!is_undefined(_r) && _r[1] == 140, "boots cross center after one second");
    bb_update_item_effects(2);
    bb_test_assert(is_undefined(bb_boots_rect(_g.boot_anim)) && _g.boots == 12, "boots disappear while protection remains");
    bb_update_item_effects(13);
    _r = bb_boots_rect(_g.boot_anim);
    bb_test_assert(!is_undefined(_r) && _r[1] == 140 && _g.boots == 0, "boots return on expiry");
    bb_update_item_effects(1);
    bb_test_assert(_g.boot_anim == -1, "boots animation ends after seventeen seconds");
    audio_stop_all(); global.G = _original; bb_refresh_details();
}

function bb_test_soda_audio() {
    var _g = global.G;
    var _rates = [30, 60, 144];
    for (var _ri = 0; _ri < 3; _ri++) {
        _g.px = 0; _g.pz = 0; _g.state = "play"; _g.gameover = false;
        _g.baldi_active = true; _g.baldi_x = 0; _g.baldi_z = -0.55;
        _g.baldi_move = 0.2; _g.baldi_cd = 0; _g.baldi_wait = 1;
        _g.baldi_extra = 0; _g.sprays = [{x:0,z:0,dx:0,dz:-1,life:30}];
        for (var _step = 0; _step < _rates[_ri]; _step++) {
            bb_update_sprays(1/_rates[_ri]);
            bb_update_baldi(1/_rates[_ri]);
        }
        bb_test_assert(!_g.gameover && _g.baldi_z < -4, "point-blank soda holds Baldi at " + string(_rates[_ri]) + "fps");
        _g.sprays = [];
        bb_update_sprays(1/_rates[_ri]);
        bb_test_assert(!_g.baldi_sprayed, "soda releases on expiry");
    }
    _g.baldi_x = 0; _g.baldi_z = -2.3; _g.baldi_move = 0.2;
    _g.sprays = [{x:0,z:-0.7,dx:0,dz:-1,life:30}];
    bb_update_sprays(0.1); bb_update_baldi(0.1);
    bb_test_assert(_g.baldi_sprayed && !_g.gameover, "fast slap cannot cross spray between frames");
    _g.sprays = [{x:0,z:2.8,dx:0,dz:1,life:30}];
    bb_update_sprays(0.1);
    bb_test_assert(array_length(_g.sprays) == 1, "soda trigger survives a wall");
    _g.sprays = []; _g.baldi_sprayed = false;
    _g.spoop_mode = false; _g.baldi_wait = 0; _g.baldi_anger = 0;
    bb_activate_spoop();
    bb_test_assert(_g.baldi_wait > 2, "first wrong answer initializes slap interval");
    _g.baldi_cd = 0; _g.audio_log = [];
    for (var _step = 0; _step < 120; _step++) bb_update_baldi(1/60);
    var _slaps = 0;
    for (var _i = 0; _i < array_length(_g.audio_log); _i++) {
        if (_g.audio_log[_i].clip == snd_bal_slap) _slaps += 1;
    }
    bb_test_assert(_slaps >= 1 && _slaps <= 2, "no per-frame ruler audio after first wrong answer");
    bb_test_assert(bb_world_sound(snd_door_open, 1000, 1000) == -1, "distant door is inaudible");
    _g.spoop_mode = false; _g.notebooks = 1;
    bb_yctp_open(); bb_audio_update(0.01);
    var _intro = _g.voices.math.handle;
    bb_test_assert(_g.voices.math.queue[0] == global.S.bal_intro && _g.voices.math.head == 1, "math intro begins one voice queue");
    _g.yctp_input = string(_g.yctp_ans); bb_yctp_submit();
    bb_test_assert(!audio_is_playing(_intro) && _g.voices.math.head == 0, "answer interrupts previous speech");
    bb_audio_update(0.01);
    var _praise = _g.voices.math.handle;
    _g.yctp_input = "99999"; bb_yctp_submit();
    bb_audio_update(0.01);
    bb_test_assert(_g.spoop_mode && array_length(_g.voices.math.queue) == 0 && !audio_is_playing(_praise), "wrong answer clears all math speech");
    bb_yctp_close();
    bb_test_assert(array_length(_g.voices.math.queue) == 0, "closing pad leaves no deferred how-to audio");
    _g.gameover = false; _g.audio_log = [];
    bb_gameover(); bb_gameover();
    bb_test_assert(array_length(_g.audio_log) == 1 && _g.audio_log[0].clip == global.S.aud_buzz, "game-over plays source buzz only once");
}

function bb_test_pixel_near(_a, _b) {
    return abs(colour_get_red(_a)-colour_get_red(_b)) <= 2
        && abs(colour_get_green(_a)-colour_get_green(_b)) <= 2
        && abs(colour_get_blue(_a)-colour_get_blue(_b)) <= 2;
}

function bb_test_surface_buffer(_surface) {
    var _buffer = buffer_create(surface_get_width(_surface)*surface_get_height(_surface)*4, buffer_fixed, 1);
    buffer_get_surface(_buffer, _surface, 0);
    return _buffer;
}

function bb_test_surface_difference(_a, _b, _step) {
    var _ba = bb_test_surface_buffer(_a), _bb = bb_test_surface_buffer(_b), _different = 0;
    var _w = surface_get_width(_a), _h = surface_get_height(_a);
    for (var _y = 0; _y < _h; _y += _step) {
        for (var _x = 0; _x < _w; _x += _step) {
            var _offset = (_y*_w+_x)*4;
            if ((buffer_peek(_ba,_offset,buffer_u32)&16777215) != (buffer_peek(_bb,_offset,buffer_u32)&16777215)) _different += 1;
        }
    }
    buffer_delete(_ba); buffer_delete(_bb);
    return _different;
}

function bb_test_world_filter() {
    // Use the actual runtime-loaded floor PNG at its world scale and a shallow
    // viewing angle. Compare a tiny camera movement, where moire is most visible.
    var _spr=global.map_textures[$ "tex/map/TileFloor.png"];
    var _frames=[surface_create(640,480),surface_create(640,480)];
    var _motion=[],_means=[];
    for (var _mode=0;_mode<2;_mode++) {
        for (var _frame=0;_frame<2;_frame++) {
            surface_set_target(_frames[_frame]);
            bb3d_begin(_frame*.015,1,0,0,640/480);
            bb3d_world_filter(_mode==1);
            var _vb=global.vb_bill;
            vertex_begin(_vb,global.vf_3d);
            bb3d_quad(_vb,-40,0,-80,0,0,-40,0,-2,0,39,
                40,0,-2,40,39,40,0,-80,40,0,c_white,1);
            vertex_end(_vb);
            vertex_submit(_vb,pr_trianglelist,sprite_get_texture(_spr,0));
            surface_reset_target();bb3d_end();
        }
        surface_save(_frames[0],_mode==0?"bb_floor_point_check.png":"bb_floor_filtered_check.png");
        var _a=bb_test_surface_buffer(_frames[0]),_b=bb_test_surface_buffer(_frames[1]);
        var _delta=0,_mean=0,_samples=0;
        for (var _y=252;_y<310;_y++) for (var _x=80;_x<560;_x++) {
            var _offset=(_y*640+_x)*4;
            for (var _channel=0;_channel<3;_channel++) {
                var _value=buffer_peek(_a,_offset+_channel,buffer_u8);
                _delta+=abs(_value-buffer_peek(_b,_offset+_channel,buffer_u8));
                _mean+=_value;_samples++;
            }
        }
        array_push(_motion,_delta/_samples);array_push(_means,_mean/_samples);
        buffer_delete(_a);buffer_delete(_b);
    }
    show_debug_message("BB_FILTER_MOTION: point="+string(_motion[0])+" filtered="+string(_motion[1]));
    bb_test_assert(_motion[0]>1 && _motion[1]<_motion[0]*.65,
        "world filtering reduces distant floor shimmer by at least 35 percent");
    bb_test_assert(_means[1]>30 && abs(_means[1]-_means[0])<10,
        "filtered floor preserves source brightness while reducing aliasing");
    surface_free(_frames[0]);surface_free(_frames[1]);bb_ui_begin();
}

function bb_test_presentation_render() {
    show_debug_message("BB_TEST_STAGE: presentation render");
    bb_test_world_filter();
    var _mat = [matrix_get(matrix_world), matrix_get(matrix_view), matrix_get(matrix_projection)];
    var _saved = variable_clone(global.G);
    var _expected = surface_create(128, 128), _actual = surface_create(128, 128);
    // Compare real 3D atlas sprites to GameMaker's own 2D sprite renderer.
    var _sprites = [spr_zesty, spr_bsoda, spr_notebook, global.PS.item5];
    for (var _si = 0; _si < array_length(_sprites); _si++) {
        var _spr = _sprites[_si];
        surface_set_target(_expected);
        bb_ui_begin();
        matrix_set(matrix_world, matrix_build_identity());
        matrix_set(matrix_view, matrix_build_identity());
        matrix_set(matrix_projection, matrix_build_projection_ortho(128, -128, 0, 100));
        draw_clear(c_fuchsia);
        var _sx = 128/sprite_get_width(_spr), _sy = 128/sprite_get_height(_spr);
        draw_sprite_ext(_spr, 0, -64+sprite_get_xoffset(_spr)*_sx, -64+sprite_get_yoffset(_spr)*_sy, _sx, _sy, 0, c_white, 1);
        surface_reset_target();
        surface_set_target(_actual);
        bb3d_begin(0, 0, 0, 0, 1);
        draw_clear(c_fuchsia);
        var _span = 2*tan(degtorad(75*0.5));
        bb3d_draw_billboard(_spr, 0, 0, 0, -1, _span, _span, 0, 0, c_white);
        surface_reset_target(); bb3d_end();
        var _bad = 0;
        for (var _y = 8; _y < 128; _y += 8) {
            for (var _x = 8; _x < 128; _x += 8) {
                if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
            }
        }
        bb_test_assert(_bad <= 8, "atlas sprite matches 2D reference " + sprite_get_name(_spr) + " mismatches=" + string(_bad));
    }
    surface_free(_expected); surface_free(_actual);
    _expected = surface_create(640, 480); _actual = surface_create(640, 480);
    matrix_set(matrix_world, matrix_build_identity());
    matrix_set(matrix_view, matrix_build_lookat(320, 240, -10, 320, 240, 0, 0, 1, 0));
    // Explicit top-left GUI projection, independent of the window's letterboxing.
    matrix_set(matrix_view, matrix_build( -320, -240, 0, 0, 0, 0, 1, 1, 1));
    matrix_set(matrix_projection, matrix_build_projection_ortho(640, -480, 0, 100));
    // The startup screen is the source bitmap at its authored 640x480 size.
    surface_set_target(_expected);bb_ui_begin();draw_clear(c_fuchsia);
    draw_sprite(global.PS.warning_screen,0,0,0);surface_reset_target();
    surface_set_target(_actual);draw_clear(c_lime);bb_warning_draw();surface_reset_target();
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)==0,
        "startup warning matches the source bitmap and fully covers the title");
    surface_save(_actual,"bb_warning_check.png");
    global.G.state="play";global.G.gameover=false;global.G.win=false;
    global.G.pause=true;global.G.pause_hover=-1;global.G.pause_time=0;
    surface_set_target(_expected);draw_clear(c_white);bb_pause_draw();surface_reset_target();
    bb_test_assert(surface_getpixel(_expected,20,400)==c_white,
        "source transparent pause blocker leaves the scene background unchanged");
    for (var _pi=0;_pi<2;_pi++) {
        global.G.pause_hover=_pi;global.G.pause_time=.3;
        surface_set_target(_actual);draw_clear(c_white);bb_pause_draw();surface_reset_target();
        bb_test_assert(bb_test_surface_difference(_expected,_actual,2)>30,
            "pause head hover renders the source animation "+string(_pi));
        surface_save(_actual,_pi==0?"bb_pause_yes_check.png":"bb_pause_no_check.png");
    }
    global.G.pause_hover=-1;global.G.pause_time=0;
    surface_set_target(_actual);draw_clear(c_white);bb_pause_draw();surface_reset_target();
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)==0,
        "leaving pause buttons restores both idle portraits");
    var _pause_layout=bb_yctp_text_layout(global.P.pause.text.value,global.P.pause.text),_pause_lines=[];
    for (var _pi=0;_pi<array_length(_pause_layout);_pi++) {
        var _glyph=_pause_layout[_pi];
        if (_pi==0 || _glyph.baseline!=_pause_layout[_pi-1].baseline) array_push(_pause_lines,_glyph.baseline);
    }
    bb_test_assert(array_length(_pause_lines)==3,"source pause text fits three authored centered lines");
    global.G.pause=false;
    surface_set_target(_expected);bb_loading_draw(0);surface_reset_target();
    surface_set_target(_actual);bb_loading_draw(.25);surface_reset_target();
    bb_test_assert(surface_getpixel(_actual,20,20)==c_white
        && surface_getpixel(_actual,620,460)==c_white,"loading fills the screen with source white background");
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)>100,
        "source loading spin frames produce visible GPU animation");
    surface_save(_actual,"bb_loading_spin_check.png");
    surface_set_target(_expected);bb_ui_begin();draw_clear(c_white);
    bb_ui_texture(bb_loading_texture(.25),global.P.menu.loading.rect);surface_reset_target();
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)>30,
        "loading renders source LOAD label over spinning head");
    var _start_button=global.P.menu.buttons.start;
    surface_set_target(_expected);bb_ui_begin();draw_clear(c_fuchsia);
    bb_menu_asset_draw(_start_button.normal,_start_button.rect,_start_button.preserve);surface_reset_target();
    surface_set_target(_actual);bb_ui_begin();draw_clear(c_fuchsia);
    bb_menu_asset_draw(_start_button.selected,_start_button.rect,_start_button.preserve);surface_reset_target();
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)>20,
        "source START normal and selected crops render distinct pixels");
    var _story_text=global.P.menu.text.story;
    surface_set_target(_expected);bb_ui_begin();draw_clear(c_white);
    bb_yctp_text(_story_text.value,_story_text,false,false,false);surface_reset_target();
    surface_set_target(_actual);bb_ui_begin();draw_clear(c_white);
    bb_yctp_text(_story_text.value,_story_text,false,false,true);surface_reset_target();
    var _story_underline_pixels=bb_test_surface_difference(_expected,_actual,1);
    bb_test_assert(_story_underline_pixels>100,
        "Story hover underline reaches the visible GPU surface pixels="+string(_story_underline_pixels));
    surface_save(_actual,"bb_menu_story_hover_check.png");
    var _endless_value=global.P.menu.text.endless.value+"\nHigh Score: 999999 Notebooks";
    var _endless_text=bb_menu_endless_text_node(_endless_value);
    surface_set_target(_expected);bb_ui_begin();draw_clear(c_white);
    bb_yctp_text(_endless_value,_endless_text,false,true,false);surface_reset_target();
    surface_set_target(_actual);bb_ui_begin();draw_clear(c_white);
    bb_yctp_text(_endless_value,_endless_text,false,true,true);surface_reset_target();
    var _endless_underline_pixels=bb_test_surface_difference(_expected,_actual,1);
    bb_test_assert(_endless_underline_pixels>100,
        "Endless hover underline uses visible source thickness pixels="+string(_endless_underline_pixels));
    surface_save(_actual,"bb_menu_endless_hover_check.png");
    surface_set_target(_expected); bb_ui_begin(); draw_clear_alpha(c_black, 0);
    bb_ui_texture("slots", global.P.hud.ItemSlots.rect);
    surface_reset_target();
    global.G.inv = [-1, -1, -1];
    surface_set_target(_actual); draw_clear(c_black); bb_present_hud(global.G, 640, 480); surface_reset_target();
    bb_test_assert(surface_getpixel(_actual, 585, 20) == c_white && surface_getpixel(_actual, 620, 20) == c_white,
        "unselected inventory slots have white backing beneath frame");
    global.G.inv = [1, 4, 9];
    surface_set_target(_actual); draw_clear(c_black); bb_present_hud(global.G, 640, 480); surface_reset_target();
    var _bad = 0, _checked = 0;
    for (var _y = 2; _y < 65; _y += 3) {
        for (var _x = 513; _x < 639; _x += 3) {
            if (((surface_getpixel_ext(_expected, _x, _y) >> 24) & 255) < 254) continue;
            _checked += 1;
            if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
        }
    }
    bb_test_assert(_checked > 50 && _bad == 0, "HUD frame remains fully visible above populated item slots");
    surface_save(_actual, "bb_hud_check.png");
    bb_yctp_layout_init();
    global.G.state = "yctp"; global.G.yctp_q = 1; global.G.yctp_end = false;
    global.G.yctp_corrupt = false; global.G.yctp_marks = [1, -1, 0];
    surface_set_target(_expected); draw_clear(c_black); bb_ui_begin();
    bb_ui_texture(global.P.yctp.YCTP.texture, global.P.yctp.YCTP.rect);
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) bb_ui_texture(global.yctp_pad[_i].texture, global.yctp_pad[_i].rect);
    surface_reset_target();
    surface_set_target(_actual); draw_clear(c_black); bb_present_yctp(-1,-1); surface_reset_target();
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) {
        var _b = global.yctp_pad[_i], _bad = 0;
        for (var _y = ceil(_b.y1)+3; _y < _b.y2-3; _y += 6) {
            for (var _x = ceil(_b.x1)+3; _x < _b.x2-3; _x += 6) {
                if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
            }
        }
        bb_test_assert(_bad == 0, "YCTP source button placement " + string(_b.v));
        bb_test_assert(bb_yctp_pad_at((_b.x1+_b.x2)*0.5, (_b.y1+_b.y2)*0.5) == _b.v, "YCTP visible button hit area " + string(_b.v));
    }
    surface_save(_actual, "bb_yctp_check.png");
    // Exercise the real pad drawing path with each pointer position. Only the
    // hovered key may change, and leaving the keypad restores the normal image.
    surface_set_target(_expected); bb_present_yctp(-1,-1); surface_reset_target();
    var _normal_pad=bb_test_surface_buffer(_expected);
    for (var _i=0;_i<array_length(global.yctp_pad);_i++) {
        var _b=global.yctp_pad[_i];
        surface_set_target(_actual); bb_present_yctp((_b.x1+_b.x2)*.5,(_b.y1+_b.y2)*.5); surface_reset_target();
        var _hover_pad=bb_test_surface_buffer(_actual),_changed=0,_outside=0;
        for (var _y=0;_y<480;_y+=2) for (var _x=0;_x<640;_x+=2) {
            var _offset=(_y*640+_x)*4;
            if (bb_test_pixel_near(buffer_peek(_normal_pad,_offset,buffer_u32)&16777215,
                buffer_peek(_hover_pad,_offset,buffer_u32)&16777215)) continue;
            if (_x>=floor(_b.x1) && _x<=ceil(_b.x2) && _y>=floor(_b.y1) && _y<=ceil(_b.y2)) _changed++;
            else _outside++;
        }
        buffer_delete(_hover_pad);
        bb_test_assert(_changed>20 && _outside==0,
            "YCTP hover changes only the targeted key "+string(_b.v)+" pixels="+string(_changed));
    }
    buffer_delete(_normal_pad);
    surface_save(_actual,"bb_yctp_hover_check.png");
    surface_set_target(_actual); bb_present_yctp(-1,-1); surface_reset_target();
    bb_test_assert(bb_test_surface_difference(_expected,_actual,2)==0,
        "YCTP pointer exit restores every normal key");
    // Opposite backgrounds must produce the same complete pad, including its holes.
    surface_set_target(_expected); draw_clear(c_lime); bb_present_yctp(); surface_reset_target();
    surface_set_target(_actual); draw_clear(c_fuchsia); bb_present_yctp(); surface_reset_target();
    var _different = bb_test_surface_difference(_actual, _expected, 8);
    bb_test_assert(_different == 0, "pad is fully opaque over every scene background");
    bb_test_assert(surface_getpixel(_actual, 0, 0) == c_black && surface_getpixel(_actual, 639, 479) == c_black, "pad outer background is black");
    bb_test_assert(surface_getpixel(_actual, 440, 210) == c_white && surface_getpixel(_actual, 430, 330) == c_white, "question and answer have white backing inside shell");
    // White panels, face and result marks must never paint over opaque shell pixels.
    global.G.yctp_end = true; global.G.yctp_msg = "";
    surface_set_target(_actual); bb_present_yctp(); surface_reset_target();
    surface_set_target(_expected); draw_clear_alpha(c_black, 0); bb_ui_texture(global.P.yctp.YCTP.texture, global.P.yctp.YCTP.rect); surface_reset_target();
    var _over = 0, _opaque = 0;
    var _ba = bb_test_surface_buffer(_actual), _be = bb_test_surface_buffer(_expected);
    for (var _y = 100; _y < 420; _y += 3) {
        for (var _x = 100; _x < 470; _x += 3) {
            var _offset = (_y*640+_x)*4, _pixel = buffer_peek(_be,_offset,buffer_u32);
            if (((_pixel >> 24) & 255) < 254) continue;
            _opaque += 1;
            if (!bb_test_pixel_near(buffer_peek(_ba,_offset,buffer_u32)&16777215, _pixel&16777215)) _over += 1;
        }
    }
    buffer_delete(_ba); buffer_delete(_be);
    bb_test_assert(_opaque > 100 && _over == 0, "shell stays above panels, face and result marks");
    global.G.yctp_end = false;
    // Source glyphs must be actual letter shapes, at the authored top-left baseline.
    surface_set_target(_actual); draw_clear(c_white); bb_yctp_text("SOLVE MATH Q1: \n \n3+2=", global.P.yctp.question); surface_reset_target();
    var _ink = 0, _left = 640, _top = 480, _right = 0, _bottom = 0;
    for (var _y = 140; _y < 290; _y++) {
        for (var _x = 200; _x < 450; _x++) {
            if (surface_getpixel(_actual, _x, _y) == c_white) continue;
            _ink += 1; _left = min(_left, _x); _top = min(_top, _y); _right = max(_right, _x); _bottom = max(_bottom, _y);
        }
    }
    bb_test_assert(_ink > 300 && _ink < 2800, "source font draws letter silhouettes, ink=" + string(_ink));
    bb_test_assert(_left >= 208 && _left <= 212 && _top >= 151 && _top <= 156 && _right < 445 && _bottom < 286,
        "question text follows original left/top position: " + string(_left) + "," + string(_top));
    var _messages = ["WOW! YOU EXIST!", "I HEAR MATH THAT BAD", "I GET ANGRIER FOR EVERY PROBLEM YOU GET WRONG", "I HEAR EVERY DOOR YOU OPEN"];
    for (var _mi = 0; _mi < array_length(_messages); _mi++) {
        var _layout = bb_yctp_text_layout(_messages[_mi], global.P.yctp.question), _fits = true;
        for (var _i = 0; _i < array_length(_layout); _i++) {
            var _glyph = _layout[_i];
            if (_glyph.y + _glyph.src[3] * _glyph.scale > 286) _fits = false;
        }
        bb_test_assert(_fits, "end message fits white text area " + string(_mi));
    }
    global.G.yctp_input = "-1234567";
    surface_set_target(_actual); draw_clear(c_fuchsia); bb_yctp_text(global.G.yctp_input, global.P.yctp.answer, true); surface_reset_target();
    bb_test_assert(surface_getpixel(_actual, 450, 325) == c_fuchsia && surface_getpixel(_actual, 240, 325) == c_fuchsia, "long answer stays clipped to input viewport");
    global.G.yctp_input = "5"; global.G.yctp_a = 3; global.G.yctp_b = 2; global.G.yctp_op = "+";
    global.G.yctp_face_visible = true; global.G.yctp_face_state = "talk"; global.G.yctp_face_time = 0.1;
    surface_set_target(_actual); draw_clear(c_fuchsia); bb_present_yctp(); surface_reset_target();
    surface_save(_actual, "bb_yctp_check.png");
    global.G.yctp_face_state = "frown"; global.G.yctp_face_time = 0.7;
    global.G.yctp_q = 3; global.G.yctp_corrupt = true; global.G.yctp_input = "";
    global.G.yctp_bad1 = "1234+(5678X9012="; global.G.yctp_bad2 = "(983/412)+6789="; global.G.yctp_bad3 = "3456+(7890X1234=";
    surface_set_target(_actual); draw_clear(c_fuchsia); bb_present_yctp(); surface_reset_target();
    surface_save(_actual, "bb_yctp_corrupt_check.png");
    global.G.state = "play"; global.G.detention = 30; global.G.play_lock = 0; global.G.boot_anim = -1;
    show_debug_message("BB_TEST_STAGE: HUD effects");
    surface_set_target(_actual); draw_clear(make_colour_rgb(180,180,180)); bb_draw_hud_effects(); surface_reset_target();
    surface_save(_actual, "bb_detention_check.png");
    global.G.detention = 0; global.G.play_lock = 1; global.G.play_need = 3; global.G.rope_delay = 0; global.G.rope_time = .25;
    surface_set_target(_actual); draw_clear(make_colour_rgb(180,180,180)); bb_draw_hud_effects(); surface_reset_target();
    surface_save(_actual, "bb_rope_check.png");
    global.G.play_lock = 0; global.G.boot_anim = 1;
    surface_set_target(_actual); draw_clear(make_colour_rgb(180,180,180)); bb_draw_hud_effects(); surface_reset_target();
    surface_save(_actual, "bb_boots_check.png");
    surface_set_target(_actual); bb_ui_begin(); draw_clear(make_colour_rgb(80,120,160));
    bb_draw_finale_red(640,480); surface_reset_target();
    var _red_pixel = surface_getpixel(_actual,320,240);
    bb_test_assert(colour_get_red(_red_pixel) == 80 && colour_get_green(_red_pixel) == 0
        && colour_get_blue(_red_pixel) == 0, "first finale exit multiplies the rendered scene to full red");
    surface_free(_expected); surface_free(_actual);
    global.G = _saved;
    _actual = surface_create(128, 128);
    surface_set_target(_actual); bb3d_begin(0, 1, 2, 0, 1); draw_clear(c_fuchsia);
    bb_draw_exit_signs(); surface_reset_target(); bb3d_end();
    var _pixels = 0;
    for (var _y = 0; _y < 128; _y += 2) {
        for (var _x = 0; _x < 128; _x += 2) {
            if (surface_getpixel(_actual, _x, _y) != c_fuchsia) _pixels += 1;
        }
    }
    bb_test_assert(_pixels > 10, "authored entrance sign renders in spawn camera");
    surface_free(_actual);
    var _door=global.G.doors[0],_door_bounds=bb_door_box(_door);
    var _door_x=(_door_bounds[0]+_door_bounds[2])*.5;
    var _door_z=(_door_bounds[1]+_door_bounds[3])*.5;
    var _door_x_axis=(_door_bounds[2]-_door_bounds[0])<(_door_bounds[3]-_door_bounds[1]);
    var _face_a=surface_create(128,128),_face_b=surface_create(128,128);
    var _cam_ax=_door_x+(_door_x_axis?-2:0),_cam_az=_door_z+(_door_x_axis?0:-2);
    var _cam_bx=_door_x+(_door_x_axis?2:0),_cam_bz=_door_z+(_door_x_axis?0:2);
    _door.open=false;
    var _door_spr=global.map_textures[$ global.map.materials[$ _door.material].file];
    surface_set_target(_face_a); bb3d_begin(_cam_ax,1,_cam_az,
        arctan2(_cam_ax-_door_x,_cam_az-_door_z),1); draw_clear(c_fuchsia);
    var _door_uv=bb3d_sprite_uv_transform(_door_spr);
    gpu_set_cullmode(cull_clockwise);vertex_begin(global.vb_bill,global.vf_3d);
    bb3d_emit_vertices(global.vb_bill,_door.v,_door_uv,c_white);
    bb3d_emit_vertices(global.vb_bill,_door.v_inside,_door_uv,c_white);vertex_end(global.vb_bill);
    vertex_submit(global.vb_bill,pr_trianglelist,sprite_get_texture(_door_spr,0));
    surface_reset_target(); bb3d_end();
    surface_set_target(_face_b); bb3d_begin(_cam_bx,1,_cam_bz,
        arctan2(_cam_bx-_door_x,_cam_bz-_door_z),1); draw_clear(c_fuchsia);
    gpu_set_cullmode(cull_clockwise);vertex_begin(global.vb_bill,global.vf_3d);
    bb3d_emit_vertices(global.vb_bill,_door.v,_door_uv,c_white);
    bb3d_emit_vertices(global.vb_bill,_door.v_inside,_door_uv,c_white);vertex_end(global.vb_bill);
    vertex_submit(global.vb_bill,pr_trianglelist,sprite_get_texture(_door_spr,0));
    surface_reset_target(); bb3d_end();
    var _door_pixels=0,_door_pixels_b=0;
    for (var _y=0;_y<128;_y+=4) for (var _x=0;_x<128;_x+=4) {
        if (surface_getpixel(_face_a,_x,_y)!=c_fuchsia) _door_pixels+=1;
        if (surface_getpixel(_face_b,_x,_y)!=c_fuchsia) _door_pixels_b+=1;
    }
    var _door_face_difference=bb_test_surface_difference(_face_a,_face_b,2);
    var _door_mirror_difference=0;
    for (var _y=0;_y<128;_y+=2) for (var _x=0;_x<128;_x+=2) {
        if (!bb_test_pixel_near(surface_getpixel(_face_a,_x,_y),
            surface_getpixel(_face_b,127-_x,_y))) _door_mirror_difference+=1;
    }
    bb_test_assert(_door_pixels>100,
        "outside authored door face renders pixels="+string(_door_pixels));
    bb_test_assert(_door_pixels_b>100,
        "inside authored door face renders pixels="+string(_door_pixels_b));
    bb_test_assert(_door_face_difference<_door_mirror_difference*.5,
        "both source door faces use the same non-mirrored orientation direct="
        +string(_door_face_difference)+" mirrored="+string(_door_mirror_difference));
    surface_save(_face_a,"bb_door_out_check.png");
    surface_save(_face_b,"bb_door_in_check.png");
    surface_free(_face_a);surface_free(_face_b);
    bb_secret_begin();
    _actual = surface_create(320, 240);
    surface_set_target(_actual); bb3d_begin(global.G.px, global.G.py, global.G.pz, global.G.yaw, 4/3);
    draw_clear(c_fuchsia); bb3d_draw_world(); bb_draw_environment(); bb_draw_doors(); bb_draw_entities();
    surface_reset_target(); bb3d_end();
    bb_test_assert(surface_getpixel(_actual, 160, 120) != c_fuchsia,
        "Secret spawn view renders secretwall");
    surface_save(_actual, "bb_secret_front_check.png");
    global.G.yaw=0;
    surface_set_target(_actual); bb3d_begin(global.G.px, global.G.py, global.G.pz, 0, 4/3);
    draw_clear(c_fuchsia); bb3d_draw_world(); bb_draw_environment(); bb_draw_doors(); bb_draw_entities();
    surface_reset_target(); bb3d_end();
    var _secret_back_pixels = 0;
    for (var _y=0; _y<240; _y+=8) for (var _x=0; _x<320; _x+=8) {
        if (surface_getpixel(_actual,_x,_y) != c_fuchsia) _secret_back_pixels += 1;
    }
    bb_test_assert(_secret_back_pixels > 100,
        "turning around at Secret spawn renders the corridor and room");
    surface_save(_actual, "bb_secret_back_check.png");
    surface_free(_actual);
    _expected = surface_create(320,240); _actual = surface_create(320,240);
    global.G.px=0; global.G.pz=-23;
    surface_set_target(_expected); bb3d_begin(0,1,-23,0,4/3); draw_clear(c_fuchsia);
    bb3d_draw_world(); bb_draw_environment(); surface_reset_target(); bb3d_end();
    surface_set_target(_actual); bb3d_begin(0,1,-23,0,4/3); draw_clear(c_fuchsia);
    bb3d_draw_world(); bb_draw_environment(); bb_draw_doors(); surface_reset_target(); bb3d_end();
    bb_test_assert(bb_test_surface_difference(_actual,_expected,2) > 20,
        "Secret room renders the source green connecting door");
    surface_save(_actual, "bb_secret_door_check.png");
    surface_free(_expected); surface_free(_actual);
    var _baldi=global.E.billboards[0],_deform=_baldi.deform;
    var _spr=global.PS[$ _baldi.texture];
    var _front=bb3d_deformed_vertices(_spr,_deform,0);
    var _side=bb3d_deformed_vertices(_spr,_deform,pi/2);
    bb_test_assert(abs(_front[2][0]-_front[1][0])>3
        && abs(_front[2][2]-_front[1][2])>3,
        "Secret Baldi vertical edge retains parent shear in X and Z");
    bb_test_assert(abs(_front[1][1]-_front[0][1])>1
        && abs(_side[1][1]-_side[0][1])>1,
        "Secret Baldi width tilts with camera rotation through scaled parent");
    bb_test_assert(bb_dist2(_front[1][0],_front[1][2],_side[1][0],_side[1][2])>1,
        "Secret Baldi deformation updates with camera yaw");
    _actual=surface_create(320,240);_expected=surface_create(320,240);
    global.G.px=0;global.G.pz=-25;global.G.yaw=0;global.G.secret_time=1;
    surface_set_target(_actual);bb3d_begin(0,1,-25,0,4/3);draw_clear(c_fuchsia);
    bb3d_draw_world();bb_draw_environment();bb_draw_doors();bb_draw_entities();
    surface_reset_target();bb3d_end();
    surface_save(_actual,"bb_secret_baldi_check.png");
    surface_set_target(_expected);bb3d_begin(0,1,-25,0,4/3);draw_clear(c_fuchsia);
    bb3d_draw_world();bb_detail_meshes(global.E.meshes);
    bb3d_draw_billboard(_spr,0,_baldi.x,_baldi.y,_baldi.z,_baldi.w,_baldi.h,0,-25,c_white);
    bb_draw_doors();bb_draw_entities();surface_reset_target();bb3d_end();
    bb_test_assert(bb_test_surface_difference(_actual,_expected,2)>50,
        "Secret room GPU render includes deformed Baldi instead of rectangular billboard");
    surface_free(_actual);surface_free(_expected);
    _actual = surface_create(320,240); surface_set_target(_actual); draw_clear(c_fuchsia);
    bb_game_draw_gui(); surface_reset_target();
    var _secret_gui_pixels=0;
    for (var _y=0; _y<240; _y+=8) for (var _x=0; _x<320; _x+=8) {
        if (surface_getpixel(_actual,_x,_y) != c_fuchsia) _secret_gui_pixels += 1;
    }
    bb_test_assert(_secret_gui_pixels == 0, "Secret ending has no added four-line overlay");
    surface_free(_actual);
    global.G = _saved; bb_world_load("school_map.json", global.P.environment_file);
    matrix_set(matrix_world, _mat[0]); matrix_set(matrix_view, _mat[1]); matrix_set(matrix_projection, _mat[2]);
    bb_ui_begin();
    bb_test_world_details_render();
}

function bb_test_world_details_render() {
    show_debug_message("BB_TEST_STAGE: world details");
    var _saved = variable_clone(global.G), _g = global.G;
    var _expected = surface_create(128,128), _actual = surface_create(128,128);
    for (var _i = 0; _i < array_length(_g.exits); _i++) _g.exits[_i].down = false;
    bb_refresh_details();
    for (var _i = 0; _i < array_length(_g.exits); _i++) {
        var _e = _g.exits[_i], _s = _e.source, _b = _s.wall_bounds;
        var _dx = sign((_b[0]+_b[3])*.5-_s.origin[0]), _dz = sign((_b[2]+_b[5])*.5-_s.origin[2]);
        var _x = _s.origin[0]-_dx*2, _z = _s.origin[2]-_dz*2;
        for (var _angle = 0; _angle < 360; _angle += 45) {
            var _cx = _s.origin[0]+lengthdir_x(2,_angle), _cz = _s.origin[2]+lengthdir_y(2,_angle);
            if (!bb_blocked_world(_cx,_cz,.28,true) && bb_los(_cx,_cz,_s.origin[0],_s.origin[2])) {
                _x = _cx; _z = _cz; break;
            }
        }
        var _yaw = arctan2(_x-_s.origin[0],_z-_s.origin[2]);
        _g.px = _x; _g.pz = _z;
        surface_set_target(_expected); bb3d_begin(_x,1,_z,_yaw,1);
        bb3d_draw_world(); bb_draw_entrances(); surface_reset_target(); bb3d_end();
        surface_set_target(_actual); bb3d_begin(_x,1,_z,_yaw,1);
        bb3d_draw_world(); bb_draw_entrances(); bb_draw_exit_signs(); surface_reset_target(); bb3d_end();
        var _pixels = bb_test_surface_difference(_actual, _expected, 2);
        bb_test_assert(_pixels > 5, "exit sign visible against actual walls " + _e.name + " pixels=" + string(_pixels));
        show_debug_message("BB_TEST_STAGE: checked " + _e.name);
    }
    surface_free(_actual); surface_free(_expected);
    _actual = surface_create(640,480);
    var _e = _g.exits[0], _s = _e.source, _b = _s.wall_bounds;
    var _dx = sign((_b[0]+_b[3])*.5-_s.origin[0]), _dz = sign((_b[2]+_b[5])*.5-_s.origin[2]);
    _e.down = true; _e.used = true;
    _g.px = _s.origin[0]-_dx*2; _g.pz = _s.origin[2]-_dz*2;
    surface_set_target(_actual); bb3d_begin(_g.px,1,_g.pz,arctan2(-_dx,-_dz),640/480);
    bb3d_draw_world(); bb_draw_entrances(); surface_reset_target(); bb3d_end();
    surface_save(_actual,"bb_exit_map_check.png");
    for (var _i = 0; _i < array_length(_g.props); _i++) {
        var _p = _g.props[_i];
        if (_p.kind != "soda") continue;
        var _x = _p.x+1.4, _z = _p.z-2;
        surface_set_target(_actual); bb3d_begin(_x,1,_z,arctan2(_x-_p.x,_z-_p.z),640/480);
        bb_detail_meshes(_p.detail.meshes); surface_reset_target(); bb3d_end();
        surface_save(_actual,"bb_vending_check.png");
        break;
    }
    surface_free(_actual);
    global.G = _saved; bb_refresh_details(); bb_ui_begin();
}

function bb_test_render() {
    // Read a known front-facing quad to verify winding against GM's projection.
    var _surface = surface_create(32, 32);
    surface_set_target(_surface);
    bb3d_begin(0, 1, 0, 0, 1);
    draw_clear(c_black);
    gpu_set_cullmode(cull_clockwise);
    vertex_begin(global.vb_bill, global.vf_3d);
    bb3d_quad(global.vb_bill, -1, 0, -1, 0, 1, 1, 0, -1, 1, 1,
        1, 2, -1, 1, 0, -1, 2, -1, 0, 0, c_red, 1);
    vertex_end(global.vb_bill);
    vertex_submit(global.vb_bill, pr_trianglelist, -1);
    surface_reset_target();
    bb_test_assert(surface_getpixel(_surface, 16, 16) == c_red, "front-face render winding");
    bb3d_end();
    // Verify an authored half-wall is visible from both the corridor and room.
    var _views = [[0, -4.5, pi * 0.5], [-2, -4.5, -pi * 0.5]];
    for (var _i = 0; _i < 2; _i++) {
        surface_set_target(_surface);
        bb3d_begin(_views[_i][0], 1, _views[_i][1], _views[_i][2], 1);
        draw_clear(c_fuchsia);
        bb3d_draw_world();
        surface_reset_target();
        bb_test_assert(surface_getpixel(_surface, 16, 16) != c_fuchsia, "source half-wall renders from side " + string(_i));
        bb3d_end();
    }
    surface_free(_surface);
}
