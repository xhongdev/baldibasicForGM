function bb3d_init() {
    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_normal();
    vertex_format_add_colour();
    vertex_format_add_texcoord();
    global.vf_3d = vertex_format_end();
    global.vb_batches = [];
    global.vb_alpha = [];
    global.vb_bill = vertex_create_buffer();
}

function bb3d_free_batches() {
    var i;
    for (i = 0; i < array_length(global.vb_batches); i++) {
        vertex_delete_buffer(global.vb_batches[i].vb);
    }
    for (i = 0; i < array_length(global.vb_alpha); i++) {
        vertex_delete_buffer(global.vb_alpha[i].vb);
    }
    global.vb_batches = [];
    global.vb_alpha = [];
}

function bb3d_shutdown() {
    bb3d_free_batches();
    if (variable_global_exists("vb_bill") && global.vb_bill != -1) {
        vertex_delete_buffer(global.vb_bill);
        global.vb_bill = -1;
    }
    if (variable_global_exists("vf_3d")) {
        vertex_format_delete(global.vf_3d);
    }
}

function bb3d_vert(_vb, _x, _y, _z, _nx, _ny, _nz, _u, _v, _col, _a) {
    vertex_position_3d(_vb, _x, _y, _z);
    vertex_normal(_vb, _nx, _ny, _nz);
    vertex_colour(_vb, _col, _a);
    vertex_texcoord(_vb, _u, _v);
}

function bb3d_quad(_vb, _ax, _ay, _az, _au, _av, _bx, _by, _bz, _bu, _bv, _cx, _cy, _cz, _cu, _cv, _dx, _dy, _dz, _du, _dv, _col, _a) {
    var _nx = 0;
    var _ny = 1;
    var _nz = 0;
    bb3d_vert(_vb, _ax, _ay, _az, _nx, _ny, _nz, _au, _av, _col, _a);
    bb3d_vert(_vb, _bx, _by, _bz, _nx, _ny, _nz, _bu, _bv, _col, _a);
    bb3d_vert(_vb, _cx, _cy, _cz, _nx, _ny, _nz, _cu, _cv, _col, _a);
    bb3d_vert(_vb, _ax, _ay, _az, _nx, _ny, _nz, _au, _av, _col, _a);
    bb3d_vert(_vb, _cx, _cy, _cz, _nx, _ny, _nz, _cu, _cv, _col, _a);
    bb3d_vert(_vb, _dx, _dy, _dz, _nx, _ny, _nz, _du, _dv, _col, _a);
}

function bb3d_emit_piece(_vb, _k, _x, _z, _col, _a) {
    var _x0 = _x - 1;
    var _x1 = _x + 1;
    var _z0 = _z - 1;
    var _z1 = _z + 1;
    var _y0 = 0;
    var _y1 = 2;
    switch (_k) {
        case "floor":
            bb3d_quad(_vb, _x0, _y0, _z0, 0, 0, _x0, _y0, _z1, 0, 1, _x1, _y0, _z1, 1, 1, _x1, _y0, _z0, 1, 0, _col, _a);
            break;
        case "ceil":
            bb3d_quad(_vb, _x0, _y1, _z1, 0, 0, _x0, _y1, _z0, 0, 1, _x1, _y1, _z0, 1, 1, _x1, _y1, _z1, 1, 0, _col, _a);
            break;
        case "n":
            bb3d_quad(_vb, _x0, _y0, _z0, 0, 1, _x1, _y0, _z0, 1, 1, _x1, _y1, _z0, 1, 0, _x0, _y1, _z0, 0, 0, _col, _a);
            break;
        case "s":
            bb3d_quad(_vb, _x1, _y0, _z1, 0, 1, _x0, _y0, _z1, 1, 1, _x0, _y1, _z1, 1, 0, _x1, _y1, _z1, 0, 0, _col, _a);
            break;
        case "w":
            bb3d_quad(_vb, _x0, _y0, _z1, 0, 1, _x0, _y0, _z0, 1, 1, _x0, _y1, _z0, 1, 0, _x0, _y1, _z1, 0, 0, _col, _a);
            break;
        case "e":
            bb3d_quad(_vb, _x1, _y0, _z0, 0, 1, _x1, _y0, _z1, 1, 1, _x1, _y1, _z1, 1, 0, _x1, _y1, _z0, 0, 0, _col, _a);
            break;
    }
}

function bb3d_mat_sprite(_m) {
    switch (_m) {
        case "tile": return spr_tex_tile;
        case "carpet": return spr_tex_carpet;
        case "ceil": return spr_tex_ceiling;
        case "brick": return spr_tex_brick;
        case "window": return spr_tex_window;
        case "swing0": return spr_tex_swing0;
        case "swing60": return spr_tex_swing60;
        case "door": return spr_tex_door;
        case "door_open": return spr_tex_door_open;
        case "sky": return spr_tex_sky0;
        default: return spr_tex_brick;
    }
}

function bb3d_mat_alpha(_m) {
    return (_m == "window" || _m == "swing0" || _m == "swing60" || _m == "door" || _m == "door_open");
}

function bb3d_build_map(_map) {
    bb3d_free_batches();
    var _groups = {};
    var _quads = _map.quads;
    var _i;
    for (_i = 0; _i < array_length(_quads); _i++) {
        var _q = _quads[_i];
        var _key = _q.m + (_q.d ? "_d" : "");
        if (!variable_struct_exists(_groups, _key)) {
            _groups[$ _key] = [];
        }
        array_push(_groups[$ _key], _q);
    }
    var _names = variable_struct_get_names(_groups);
    for (_i = 0; _i < array_length(_names); _i++) {
        var _list = _groups[$ _names[_i]];
        var _sample = _list[0];
        var _vb = vertex_create_buffer();
        vertex_begin(_vb, global.vf_3d);
        var _j;
        for (_j = 0; _j < array_length(_list); _j++) {
            var _qq = _list[_j];
            var _col = _qq.d ? make_colour_rgb(90, 90, 90) : c_white;
            bb3d_emit_piece(_vb, _qq.k, _qq.x, _qq.z, _col, 1);
        }
        vertex_end(_vb);
        vertex_freeze(_vb);
        var _batch = {
            vb: _vb,
            spr: bb3d_mat_sprite(_sample.m),
            alpha: bb3d_mat_alpha(_sample.m)
        };
        if (_batch.alpha) {
            array_push(global.vb_alpha, _batch);
        } else {
            array_push(global.vb_batches, _batch);
        }
    }
}

function bb3d_begin(_px, _py, _pz, _yaw, _aspect) {
    shader_reset();
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
    gpu_set_zfunc(cmpfunc_lessequal);
    gpu_set_cullmode(cull_noculling);
    gpu_set_texfilter(false);
    gpu_set_texrepeat(true);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(16);
    draw_clear(make_colour_rgb(140, 190, 230));
    var _fov = 75;
    var _proj = matrix_build_projection_perspective_fov(_fov, -_aspect, 0.08, 220);
    matrix_set(matrix_projection, _proj);
    var _fx = -sin(_yaw);
    var _fz = -cos(_yaw);
    var _view = matrix_build_lookat(_px, _py, _pz, _px + _fx, _py, _pz + _fz, 0, 1, 0);
    matrix_set(matrix_view, _view);
    matrix_set(matrix_world, matrix_build_identity());
}

function bb3d_draw_world() {
    var _i;
    gpu_set_zwriteenable(true);
    gpu_set_blendmode(bm_normal);
    for (_i = 0; _i < array_length(global.vb_batches); _i++) {
        var _b = global.vb_batches[_i];
        vertex_submit(_b.vb, pr_trianglelist, sprite_get_texture(_b.spr, 0));
    }
    gpu_set_zwriteenable(false);
    gpu_set_blendmode_ext(bm_src_alpha, bm_inv_src_alpha);
    for (_i = 0; _i < array_length(global.vb_alpha); _i++) {
        var _a = global.vb_alpha[_i];
        vertex_submit(_a.vb, pr_trianglelist, sprite_get_texture(_a.spr, 0));
    }
    gpu_set_blendmode(bm_normal);
    gpu_set_zwriteenable(true);
}

function bb3d_draw_billboard(_spr, _img, _x, _y, _z, _w, _h, _camx, _camz, _col) {
    var _dx = _camx - _x;
    var _dz = _camz - _z;
    var _len = sqrt(_dx * _dx + _dz * _dz);
    if (_len < 0.0001) {
        _len = 0.0001;
    }
    var _rx = _dz / _len;
    var _rz = -_dx / _len;
    var _hw = _w * 0.5;
    var _hh = _h * 0.5;
    var _ax = _x - _rx * _hw;
    var _ay = _y - _hh;
    var _az = _z - _rz * _hw;
    var _bx = _x + _rx * _hw;
    var _by = _y - _hh;
    var _bz = _z + _rz * _hw;
    var _cx = _x + _rx * _hw;
    var _cy = _y + _hh;
    var _cz = _z + _rz * _hw;
    var _dx2 = _x - _rx * _hw;
    var _dy2 = _y + _hh;
    var _dz2 = _z - _rz * _hw;
    var _vb = global.vb_bill;
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _ax, _ay, _az, 0, 1, _bx, _by, _bz, 1, 1, _cx, _cy, _cz, 1, 0, _dx2, _dy2, _dz2, 0, 0, _col, 1);
    vertex_end(_vb);
    gpu_set_texrepeat(false);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(32);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(_spr, _img));
    gpu_set_texrepeat(true);
}

function bb3d_end() {
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_cullmode(cull_noculling);
    gpu_set_alphatestenable(false);
    gpu_set_texrepeat(false);
    gpu_set_blendmode(bm_normal);
    matrix_set(matrix_world, matrix_build_identity());
    matrix_set(matrix_view, matrix_build_identity());
    var _w = display_get_gui_width();
    var _h = display_get_gui_height();
    matrix_set(matrix_projection, matrix_build_projection_ortho(_w, -_h, 0.1, 16000));
}
