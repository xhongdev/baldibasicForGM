// Opt-in checks execute the real GML with the actual imported school.
function bb_test_assert(_ok, _message) {
    global.test_total += 1;
    if (!_ok) {
        global.test_failed += 1;
        show_debug_message("BB_TEST_FAIL: " + _message);
    }
}

function bb_run_selftests() {
    global.test_total = 0;
    global.test_failed = 0;
    var _saved = variable_clone(global.G);
    var _g = global.G;
    _g.notebooks = 7;
    bb_test_assert(array_length(_g.doors) == 23, "23 authored doors");
    bb_test_assert(array_length(_g.notebooks_list) == 7, "7 authored notebooks");
    bb_test_assert(ds_map_size(global.floors) == 682, "682 floor tiles");
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
    _g.baldi_active = true; _g.hear_pri = 0;
    bb_update_item_effects(29);
    bb_test_assert(!_g.alarms[0].rang, "alarm waits 30 seconds");
    bb_update_item_effects(1);
    bb_test_assert(_g.alarms[0].rang && _g.hear_pri == 8, "alarm hearing priority");
    _g.anti_hear = 30;
    var _hear_x = _g.hear_x;
    bb_hear_pri(100, 100, 9);
    bb_test_assert(_g.hear_x == _hear_x, "anti hearing suppresses sound targets");
    bb_start_playtime();
    bb_rope_tick(2.1, false);
    bb_test_assert(_g.play_need == 5 && _g.rope_delay > 1, "missed rope resets progress");
    _g.inv[0] = 9;
    bb_test_assert(bb_use_item() && _g.play_lock == 0, "scissors release rope");
    bb_test_soda_audio();
    global.G = _saved;
    bb_refresh_details();
    bb_test_yctp_state();
    bb_test_debug_menu();
    bb_test_scene_details();
    bb_test_stationary_navigation();
    bb_test_restored_gameplay();
    bb_test_ai_profile();
    audio_stop_all();
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    show_debug_message("BB_TEST_LOGIC: " + string(global.test_total) + " checks, " + string(global.test_failed) + " failures");
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

function bb_test_presentation_render() {
    show_debug_message("BB_TEST_STAGE: presentation render");
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
    surface_set_target(_actual); draw_clear(c_black); bb_present_yctp(); surface_reset_target();
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
