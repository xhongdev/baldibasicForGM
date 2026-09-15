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

function bb_load_png(_rel, _ox, _oy) {
    var _p = _rel;
    if (!file_exists(_p)) {
        _p = working_directory + _rel;
    }
    if (!file_exists(_p)) {
        return -1;
    }
    return sprite_add(_p, 1, false, false, _ox, _oy);
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
    ini_open("baldi_settings.ini");
    global.mouse_sensitivity = clamp(ini_read_real("Options", "MouseSensitivity", 1), 0.1, 3);
    global.master_volume = clamp(ini_read_real("Options", "Volume", 1), 0, 1);
    global.high_books = max(0, floor(ini_read_real("Scores", "HighBooks", 0)));
    ini_close();
    audio_master_gain(global.master_volume);
}

function bb_settings_save() {
    if (global.bb_selftest) return;
    ini_open("baldi_settings.ini");
    ini_write_real("Options", "MouseSensitivity", global.mouse_sensitivity);
    ini_write_real("Options", "Volume", global.master_volume);
    ini_write_real("Scores", "HighBooks", global.high_books);
    ini_close();
}

function bb_start_mode(_mode) {
    global.game_mode = (_mode == "endless") ? "endless" : "story";
    audio_stop_all();
    room_goto(rm_school);
}

function bb_menu_button(_label,_action,_x,_y,_w=240,_h=44) {
    return {label:_label,action:_action,x1:_x-_w*.5,y1:_y-_h*.5,x2:_x+_w*.5,y2:_y+_h*.5};
}

function bb_menu_layout(_page) {
    switch (_page) {
        case "title": return [bb_menu_button("START","modes",360,444,120),bb_menu_button("MENU","menu",555,444,110)];
        case "modes": return [bb_menu_button("STORY MODE","story",320,110),bb_menu_button("ENDLESS MODE","endless",320,240),bb_menu_button("BACK","title",80,444,120)];
        case "menu": return [bb_menu_button("HOW TO PLAY","controls",320,140),bb_menu_button("OPTIONS","options",320,220),bb_menu_button("QUIT","quit",320,300),bb_menu_button("BACK","title",80,444,120)];
        case "options": return [bb_menu_button("-","sensitivity_down",220,155,50),bb_menu_button("+","sensitivity_up",420,155,50),
            bb_menu_button("-","volume_down",220,260,50),bb_menu_button("+","volume_up",420,260,50),
            bb_menu_button("TOGGLE FULLSCREEN","fullscreen",320,345,300),bb_menu_button("BACK","menu",80,444,120)];
        default: return [bb_menu_button("BACK","menu",80,444,120)];
    }
}
