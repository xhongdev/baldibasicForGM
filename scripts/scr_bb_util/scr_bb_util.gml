function bb_pad2(_i) {
    if (_i < 10) {
        return "0" + string(_i);
    }
    return string(_i);
}

function bb_read_text(_fname) {
    var _tries = [
        _fname,
        working_directory + _fname,
        working_directory + "datafiles/" + _fname,
        "datafiles/" + _fname
    ];
    var _path = "";
    var _i;
    for (_i = 0; _i < array_length(_tries); _i++) {
        if (file_exists(_tries[_i])) {
            _path = _tries[_i];
            break;
        }
    }
    if (_path == "") {
        show_debug_message("Missing file: " + _fname);
        return "{}";
    }
    var _buf = buffer_load(_path);
    buffer_seek(_buf, buffer_seek_start, 0);
    var _s = buffer_read(_buf, buffer_text);
    buffer_delete(_buf);
    return _s;
}

function bb_hit_btn(_b) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    return (_mx >= _b.x1 && _mx <= _b.x2 && _my >= _b.y1 && _my <= _b.y2);
}

function bb_dist2(_ax, _az, _bx, _bz) {
    var _dx = _ax - _bx;
    var _dz = _az - _bz;
    return _dx * _dx + _dz * _dz;
}

function bb_point_segment_dist2(_x, _z, _ax, _az, _bx, _bz) {
    var _dx = _bx - _ax, _dz = _bz - _az;
    var _length2 = _dx*_dx + _dz*_dz;
    var _t = (_length2 > 0.000001) ? clamp(((_x-_ax)*_dx + (_z-_az)*_dz) / _length2, 0, 1) : 0;
    return bb_dist2(_x, _z, _ax + _dx*_t, _az + _dz*_t);
}

function bb_aabb_hit(_px, _pz, _r, _x0, _z0, _x1, _z1) {
    var _cx = clamp(_px, _x0, _x1);
    var _cz = clamp(_pz, _z0, _z1);
    var _dx = _px - _cx;
    var _dz = _pz - _cz;
    return (_dx * _dx + _dz * _dz) < (_r * _r);
}

function bb_key(_x, _z) {
    return string(_x) + "," + string(_z);
}

function bb_load_png(_rel, _ox, _oy, _frames = 1) {
    var _p = _rel;
    if (!file_exists(_p)) {
        _p = working_directory + _rel;
    }
    if (!file_exists(_p)) {
        return -1;
    }
    return sprite_add(_p, _frames, false, false, _ox, _oy);
}

function bb_load_png_rb(_rel) {
    var _p = _rel;
    if (!file_exists(_p)) {
        _p = working_directory + _rel;
    }
    if (!file_exists(_p)) {
        return -1;
    }
    var _s = sprite_add(_p, 1, false, false, 0, 0);
    if (_s != -1) {
        sprite_set_offset(_s, sprite_get_width(_s) * 0.5, sprite_get_height(_s) * 0.5);
    }
    return _s;
}

function bb_settings_init() {
    global.game_mode = "story";
    global.school_loading_pending = false;
    ini_open("baldi_settings.ini");
    global.mouse_sensitivity = clamp(ini_read_real("Options", "MouseSensitivity", 2), 0.1, 10);
    global.master_volume = clamp(ini_read_real("Options", "Volume", 1), 0, 1);
    global.rumble_enabled = ini_read_real("Options", "Rumble", 1) >= 0.5;
    global.analog_movement = ini_read_real("Options", "AnalogMove", 1) >= 0.5;
    global.high_books = max(0, floor(ini_read_real("Scores", "HighBooks", 0)));
    ini_close();
    audio_master_gain(global.master_volume);
}

function bb_settings_save() {
    if (global.bb_selftest) return;
    ini_open("baldi_settings.ini");
    ini_write_real("Options", "MouseSensitivity", global.mouse_sensitivity);
    ini_write_real("Options", "Volume", global.master_volume);
    ini_write_real("Options", "Rumble", global.rumble_enabled ? 1 : 0);
    ini_write_real("Options", "AnalogMove", global.analog_movement ? 1 : 0);
    ini_write_real("Scores", "HighBooks", global.high_books);
    ini_close();
}

function bb_start_mode(_mode) {
    if (global.school_loading_pending) return;
    global.game_mode = (_mode == "endless") ? "endless" : "story";
    global.school_loading_pending = true;
    room_goto(rm_school);
}

function bb_title_music_start() {
    audio_play_sound(snd_mus_intro,1,false);
    audio_play_sound(snd_bal_menu,2,false);
}

function bb_warning_accept(_pressed) {
    if (menu_page!="warning" || !_pressed) return false;
    global.warning_pending=false;
    menu_page="title";menu_selection=-1;menu_buttons=bb_menu_layout(menu_page);
    bb_title_music_start();
    return true;
}

function bb_menu_button(_key,_action) {
    var _node=global.P.menu.buttons[$ _key],_r=_node.hit;
    return {key:_key,action:_action,x1:_r[0],y1:_r[1],x2:_r[0]+_r[2],y2:_r[1]+_r[3]};
}

function bb_menu_layout(_page) {
    switch (_page) {
        case "title": return [bb_menu_button("start","modes"),bb_menu_button("main_menu","menu"),bb_menu_button("exit","quit")];
        case "modes": return [bb_menu_button("story","story"),bb_menu_button("endless","endless"),bb_menu_button("play_back","title")];
        case "menu": return [bb_menu_button("how","story_info"),bb_menu_button("options","options"),
            bb_menu_button("credits","credits"),bb_menu_button("menu_back","title")];
        case "options": return [bb_menu_button("controls","controls"),bb_menu_button("turn","sensitivity"),
            bb_menu_button("rumble","rumble"),bb_menu_button("analog","analog"),bb_menu_button("options_back","menu")];
        case "story_info": return [bb_menu_button("story_back","menu")];
        case "credits": return [bb_menu_button("credits_back","menu")];
        case "controls": return [bb_menu_button("controls_back","options")];
        default: return [];
    }
}

function bb_menu_back_page(_page) {
    switch (_page) {
        case "modes": case "menu": return "title";
        case "options": case "story_info": case "credits": return "menu";
        case "controls": return "options";
    }
    return _page;
}
