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
