// Local testing tools. Flags reset when the school is restarted.
function bb_debug_init() {
    global.G.debug = {
        open:false, tab:0, page:0, buttons:[], pages:1,
        god:false, noclip:false, stamina:false, items:false, no_rules:false,
        freeze_baldi:false, freeze_npcs:false, free_doors:false, fast:false,
        status:"Choose a tab. Changes apply immediately."
    };
}

function bb_debug_open() {
    global.G.debug.open = true;
    audio_pause_all();
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    bb_debug_layout();
}

function bb_debug_close() {
    var _g = global.G;
    _g.debug.open = false;
    _g.mouse_ready = false;
    var _play = (_g.state == "play" && !_g.pause && !_g.gameover && !_g.win);
    window_mouse_set_locked(_play);
    window_set_cursor(_play ? cr_none : cr_default);
    // Think Pad already pauses world audio. Closing this overlay must preserve it.
    if (_g.pause) return;
    if (_g.state == "yctp") {
        if (_g.voices.math.handle != -1) audio_resume_sound(_g.voices.math.handle);
        audio_resume_sound(snd_mus_learn);
        audio_resume_sound(global.S.aud_Hang);
    } else if (_g.gameover || _g.win) {
        audio_resume_sound(global.S.aud_buzz);
    } else {
        audio_resume_all();
    }
}

function bb_debug_update() {
    var _d = global.G.debug;
    if (keyboard_check_pressed(vk_f1)) {
        if (_d.open) bb_debug_close(); else bb_debug_open();
        return true;
    }
    if (!_d.open) return false;
    if (keyboard_check_pressed(vk_escape)) {
        bb_debug_close();
        return true;
    }
    if (mouse_wheel_up()) _d.page = max(0, _d.page-1);
    if (mouse_wheel_down()) _d.page = min(_d.pages-1, _d.page+1);
    if (_d.tab == 1) {
        if (keyboard_check_pressed(ord("1"))) global.G.inv_sel = 0;
        if (keyboard_check_pressed(ord("2"))) global.G.inv_sel = 1;
        if (keyboard_check_pressed(ord("3"))) global.G.inv_sel = 2;
    }
    bb_debug_layout();
    if (mouse_check_button_pressed(mb_left)) {
        for (var _i = 0; _i < array_length(_d.buttons); _i++) {
            var _b = _d.buttons[_i];
            if (bb_hit_btn(_b)) {
                bb_debug_action(_b.action, _b.value);
                break;
            }
        }
    }
    return true;
}

function bb_debug_safe_position(_x, _z) {
    var _g = global.G;
    if (!bb_blocked_world(_x, _z, _g.radius, true)) return [_x, _z];
    var _keys = ds_map_keys_to_array(global.floors);
    var _best = [global.map.player[0], global.map.player[2]];
    var _distance = 1000000000;
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _p = string_split(_keys[_i], ",");
        var _px = real(_p[0]), _pz = real(_p[1]);
        var _dd = bb_dist2(_px, _pz, _x, _z);
        if (_dd < _distance && !bb_blocked_world(_px, _pz, _g.radius, true)) {
            _best = [_px, _pz]; _distance = _dd;
        }
    }
    return _best;
}

function bb_debug_teleport(_x, _z, _look_x, _look_z) {
    var _g = global.G;
    if (_g.state == "yctp") bb_yctp_close();
    if (_g.gameover || _g.win) {
        audio_stop_all();
        if (!_g.spoop_mode) audio_play_sound(snd_mus_school, 1, true);
    }
    _g.gameover = false; _g.win = false; _g.over_t = 0;
    bb_end_playtime();
    _g.guilt = 0; _g.prin_chase = false;
    var _p = bb_debug_safe_position(_x, _z);
    _g.px = _p[0]; _g.pz = _p[1];
    if (bb_dist2(_g.px, _g.pz, _look_x, _look_z) > 0.001) {
        _g.yaw = arctan2(_g.px-_look_x, _g.pz-_look_z);
    }
    _g.mouse_ready = false;
    _g.debug.status = "Teleported to X=" + string_format(_g.px, 0, 2) + " Z=" + string_format(_g.pz, 0, 2);
}

function bb_debug_focus(_x, _z) {
    // Arrive facing the target at interaction distance, rather than inside it.
    for (var _i = 0; _i < 8; _i++) {
        var _angle = global.G.yaw + _i*pi/4;
        var _px = _x + sin(_angle)*1.2, _pz = _z + cos(_angle)*1.2;
        if (!bb_blocked_world(_px, _pz, global.G.radius, true) && bb_los(_px, _pz, _x, _z)) {
            bb_debug_teleport(_px, _pz, _x, _z);
            return;
        }
    }
    bb_debug_teleport(_x, _z, _x, _z);
}

function bb_debug_release_detention() {
    var _g = global.G;
    _g.detention = 0; _g.guilt = 0; _g.prin_chase = false;
    var _index = bb_office_door();
    if (_index >= 0) {
        _g.doors[_index].locked = false;
        _g.doors[_index].lock_cd = 0;
    }
    bb_voice_clear("principal");
}

function bb_debug_notebooks(_count) {
    var _g = global.G;
    if (_g.state == "yctp") bb_yctp_close();
    _g.notebooks = clamp(_count, 0, array_length(_g.notebooks_list));
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) _g.notebooks_list[_i].taken = (_i < _g.notebooks);
    _g.exit_open = (_g.notebooks >= 7);
    _g.exit_got = 0; _g.final_red = 0; _g.win = false;
    if (_g.finale_sound != -1) audio_stop_sound(_g.finale_sound);
    _g.finale_sound = -1; _g.finale_loop = false;
    for (var _i = 0; _i < array_length(_g.exits); _i++) {
        _g.exits[_i].used = false;
        _g.exits[_i].down = _g.spoop_mode && !_g.exit_open;
    }
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        var _door = _g.doors[_i];
        if (_door.kind == "swing") _door.locked = bb_swing_blocked(_door);
    }
    _g.debug.status = "Notebooks set to " + string(_g.notebooks) + "; exit progress reset.";
}

function bb_debug_answer() {
    var _g = global.G;
    if (_g.state != "yctp" || _g.yctp_end) return;
    _g.yctp_corrupt = false;
    _g.yctp_input = string(_g.yctp_ans);
    bb_yctp_submit();
}

function bb_debug_baldi_here() {
    var _g = global.G;
    var _fx = -sin(_g.yaw), _fz = -cos(_g.yaw);
    // Keep the test encounter on visible, walkable ground in front of the player.
    var _found = false;
    for (var _dist = 6; _dist >= 2; _dist -= 0.5) {
        var _x = _g.px + _fx*_dist, _z = _g.pz + _fz*_dist;
        if (!bb_blocked_world(_x, _z, 0.3, true) && bb_los(_g.px, _g.pz, _x, _z)) {
            if (!_g.spoop_mode) bb_activate_spoop();
            _g.baldi_x = _x; _g.baldi_z = _z;
            _g.baldi_cd = 1; _g.baldi_move = 0; _g.baldi_sprayed = false;
            _g.hear_x = _g.px; _g.hear_z = _g.pz; _g.hear_pri = 0;
            _found = true;
            break;
        }
    }
    _g.debug.status = _found ? "Baldi placed ahead. Close menu to test." : "Face an open corridor with at least 2 units of space.";
}

function bb_debug_action(_action, _value = 0) {
    var _g = global.G, _d = _g.debug;
    switch (_action) {
        case "close": bb_debug_close(); return;
        case "tab": _d.tab = _value; _d.page = 0; break;
        case "page": _d.page = clamp(_d.page+_value, 0, _d.pages-1); break;
        case "toggle":
            _d[$ _value] = !_d[$ _value];
            if (_value == "noclip" && !_d.noclip) {
                var _p = bb_debug_safe_position(_g.px, _g.pz);
                _g.px = _p[0]; _g.pz = _p[1];
            }
            if (_value == "no_rules" && _d.no_rules) bb_debug_release_detention();
            if (_value == "stamina" && _d.stamina) _g.stamina = _g.stamina_max;
            if (_value == "free_doors") {
                for (var _i = 0; _i < array_length(_g.doors); _i++) {
                    var _door = _g.doors[_i];
                    if (_d.free_doors) { _door.locked = false; _door.lock_cd = 0; }
                    else if (_door.kind == "swing") _door.locked = bb_swing_blocked(_door);
                }
            }
            _d.status = _value + ": " + (_d[$ _value] ? "ON" : "OFF");
            break;
        case "refill": _g.stamina = _g.stamina_max; _d.status = "Stamina refilled."; break;
        case "slot": _g.inv_sel = _value; break;
        case "item": _g.inv[_g.inv_sel] = _value; _d.status = "Slot " + string(_g.inv_sel+1) + ": " + bb_item_name(_value); break;
        case "clear_items": _g.inv = [-1, -1, -1]; _d.status = "Inventory cleared."; break;
        case "detention": bb_debug_release_detention(); _d.status = "Detention and rule chase cleared."; break;
        case "rope_end": bb_end_playtime(); _d.status = "Jump rope released."; break;
        case "spawn": bb_debug_teleport(global.map.player[0], global.map.player[2], 0, -4); break;
        case "office": bb_debug_teleport(1, -32, 5, -31.5); break;
        case "notebook": var _n = _g.notebooks_list[_value]; bb_debug_focus(_n.x, _n.z); break;
        case "prop": var _p = _g.props[_value]; bb_debug_focus(_p.x, _p.z); break;
        case "exit": var _e = global.P.exit_signs[_value]; bb_debug_focus(_e.x, _e.z); break;
        case "door": var _door = _g.doors[_value]; var _face = bb_door_face(_door); bb_debug_teleport(_door.x, _door.z, _face[0], _face[1]); break;
        case "chase": bb_activate_spoop(); _d.status = "Pursuit active."; break;
        case "baldi_here": bb_debug_baldi_here(); break;
        case "soda_test":
            bb_debug_baldi_here();
            _g.inv = [4, 4, 4]; _g.inv_sel = 0;
            _d.freeze_baldi = false; _d.freeze_npcs = true;
            break;
        case "anger": _g.baldi_anger = max(0.5, _g.baldi_anger+_value); bb_baldi_recalc_wait(); _d.status = "Baldi anger: " + string(_g.baldi_anger); break;
        case "books": bb_debug_notebooks(_value); break;
        case "doors_open":
            _d.free_doors = true;
            for (var _i = 0; _i < array_length(_g.doors); _i++) {
                var _door = _g.doors[_i];
                _door.locked = false; _door.lock_cd = 0; _door.open = true; _door.t = 3;
            }
            _d.status = "Doors opened; Ignore door locks enabled.";
            break;
        case "doors_close":
            for (var _i = 0; _i < array_length(_g.doors); _i++) { _g.doors[_i].open = false; _g.doors[_i].t = 0; }
            _d.status = "Doors closed.";
            break;
        case "pickups":
            for (var _i = 0; _i < array_length(_g.items); _i++) _g.items[_i].taken = false;
            _d.status = "All pickups restored, including the reward quarter.";
            break;
        case "math":
            _g.pause = false;
            if (_g.state != "yctp") bb_yctp_open();
            _d.status = "Think Pad opened. Close menu to interact.";
            break;
        case "answer": bb_debug_answer(); _d.status = "Current question accepted (including impossible questions)."; break;
        case "math_finish":
            if (_g.state == "yctp") {
                for (var _i = 0; _i < 3 && !_g.yctp_end; _i++) bb_debug_answer();
                bb_yctp_close();
                _d.status = "Think Pad completed.";
            } else _d.status = "Open the Think Pad first.";
            break;
        case "rope": bb_start_playtime(); _d.status = "Jump rope started. Close menu to play."; break;
        case "restart": audio_stop_all(); room_restart(); return;
    }
    if (_d.open) {
        // Actions may open/close the pad or start a sound. Keep the overlay modal.
        audio_pause_all();
        window_mouse_set_locked(false);
        window_set_cursor(cr_default);
        bb_debug_layout();
    }
}

function bb_debug_player_move(_dx, _dz) {
    var _g = global.G;
    if (_g.debug.noclip) return [_g.px+_dx, _g.pz+_dz];
    return bb_move_slide(_g.px, _g.pz, _dx, _dz, _g.radius, true);
}

function bb_debug_button(_label, _action, _value, _x, _y, _w, _h, _selected = false) {
    array_push(global.G.debug.buttons, {label:_label, action:_action, value:_value,
        x1:_x, y1:_y, x2:_x+_w, y2:_y+_h, selected:_selected});
}

function bb_debug_layout() {
    var _g = global.G, _d = _g.debug;
    _d.buttons = [];
    bb_debug_button("Close", "close", 0, 552, 40, 68, 28);
    var _tabs = ["Player", "Items", "Teleport", "World / Flow"];
    for (var _i = 0; _i < 4; _i++) bb_debug_button(_tabs[_i], "tab", _i, 20+150*_i, 102, 144, 28, _d.tab == _i);
    var _rows = [];
    switch (_d.tab) {
        case 0:
            var _flags = [["God mode", "god"], ["No clip", "noclip"], ["Infinite stamina", "stamina"],
                ["Do not consume items", "items"], ["No rule punishment", "no_rules"],
                ["Pause Baldi AI", "freeze_baldi"], ["Pause other NPC AI", "freeze_npcs"],
                ["Ignore door locks", "free_doors"], ["Fast movement (x3)", "fast"]];
            for (var _i = 0; _i < array_length(_flags); _i++) {
                var _flag = _flags[_i];
                array_push(_rows, [(_d[$ _flag[1]] ? "[ON] " : "[OFF] ")+_flag[0], "toggle", _flag[1]]);
            }
            array_push(_rows, ["Refill stamina", "refill", 0], ["Clear detention", "detention", 0],
                ["Release jump rope", "rope_end", 0], ["Revive / return to spawn", "spawn", 0], ["Restart school", "restart", 0]);
            break;
        case 1:
            for (var _i = 0; _i < 3; _i++) array_push(_rows, [(_g.inv_sel == _i ? "[SELECTED] " : "Select ")+"slot "+string(_i+1), "slot", _i]);
            for (var _i = 1; _i <= 10; _i++) array_push(_rows, ["Give: " + bb_item_name(_i), "item", _i]);
            array_push(_rows, ["Clear inventory", "clear_items", 0]);
            break;
        case 2:
            array_push(_rows, ["Spawn", "spawn", 0], ["Principal's office", "office", 0]);
            for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) array_push(_rows, ["Notebook " + string(_i+1), "notebook", _i]);
            for (var _i = 0; _i < array_length(_g.props); _i++) array_push(_rows, [_g.props[_i].name + " " + string(_i+1), "prop", _i]);
            for (var _i = 0; _i < array_length(global.P.exit_signs); _i++) array_push(_rows, ["Exit sign " + string(_i+1), "exit", _i]);
            for (var _i = 0; _i < array_length(_g.doors); _i++) array_push(_rows, [global.map.doors[_i].source_name, "door", _i]);
            break;
        case 3:
            array_push(_rows, ["Start pursuit", "chase", 0], ["Place Baldi ahead", "baldi_here", 0],
                ["Baldi + 3 BSODA test setup", "soda_test", 0], ["Baldi anger +1", "anger", 1], ["Baldi anger -1", "anger", -1],
                ["Set notebooks: 0", "books", 0], ["Set notebooks: 1", "books", 1], ["Set notebooks: 2", "books", 2],
                ["Set notebooks: 7 / enable exits", "books", 7], ["Unlock and open all doors", "doors_open", 0],
                ["Close all doors", "doors_close", 0], ["Restore world pickups", "pickups", 0],
                ["Open Think Pad", "math", 0], ["Accept current answer", "answer", 0],
                ["Complete Think Pad", "math_finish", 0], ["Start jump rope", "rope", 0]);
            break;
    }
    _d.pages = max(1, ceil(array_length(_rows)/14));
    _d.page = clamp(_d.page, 0, _d.pages-1);
    var _first = _d.page*14;
    for (var _i = _first; _i < min(_first+14, array_length(_rows)); _i++) {
        var _row = _rows[_i], _cell = _i-_first;
        bb_debug_button(_row[0], _row[1], _row[2], 20+(_cell mod 2)*300, 144+floor(_cell/2)*36, 292, 30);
    }
    if (_d.pages > 1) {
        bb_debug_button("< Previous", "page", -1, 20, 403, 130, 26);
        bb_debug_button("Next >", "page", 1, 490, 403, 130, 26);
    }
}

function bb_debug_draw() {
    var _g = global.G, _d = _g.debug;
    bb_ui_begin();
    draw_set_font(global.fnt_small);
    if (!_d.open) {
        var _text = "F1: Cheats";
        if (_d.god) _text += " | GOD";
        if (_d.noclip) _text += " | NOCLIP";
        if (_d.freeze_baldi || _d.freeze_npcs) _text += " | AI PAUSED";
        draw_set_color(c_black); draw_text(9, 461, _text);
        draw_set_color(c_yellow); draw_text(8, 460, _text);
        return;
    }
    draw_set_alpha(0.85); draw_set_color(c_black); draw_rectangle(0, 0, 640, 480, false); draw_set_alpha(1);
    draw_set_color(make_colour_rgb(24, 31, 42)); draw_rectangle(8, 30, 632, 474, false);
    draw_set_font(global.fnt_ui); draw_set_color(c_white); draw_text(20, 43, "Cheat / Test Menu");
    draw_set_font(global.fnt_small);
    draw_text(20, 77, "X " + string_format(_g.px, 0, 2) + "  Z " + string_format(_g.pz, 0, 2)
        + "  Books " + string(_g.notebooks) + "/7  Slot " + string(_g.inv_sel+1) + "  F1 / ESC: resume");
    for (var _i = 0; _i < array_length(_d.buttons); _i++) {
        var _b = _d.buttons[_i];
        var _hover = bb_hit_btn(_b);
        draw_set_color(_b.selected ? make_colour_rgb(32, 107, 100) : (_hover ? make_colour_rgb(73, 90, 113) : make_colour_rgb(46, 59, 77)));
        draw_rectangle(_b.x1, _b.y1, _b.x2, _b.y2, false);
        draw_set_color(c_white);
        var _label = _b.label;
        if (string_width(_label) > _b.x2-_b.x1-12) {
            while (string_width(_label + "...") > _b.x2-_b.x1-12 && string_length(_label) > 1) _label = string_delete(_label, string_length(_label), 1);
            _label += "...";
        }
        draw_text(_b.x1+6, _b.y1+5, _label);
    }
    if (_d.pages > 1) {
        draw_set_halign(fa_center); draw_text(320, 407, string(_d.page+1)+" / "+string(_d.pages)); draw_set_halign(fa_left);
    }
    draw_set_color(c_yellow);
    draw_text_ext(20, 440, _d.status, 14, 596);
    bb_ui_begin();
}
