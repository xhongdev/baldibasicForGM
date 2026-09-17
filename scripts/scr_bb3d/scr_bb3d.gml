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

function bb3d_emit_jamb(_vb, _k, _x, _z, _a0, _a1, _col, _a) {
    var _y0 = 0;
    var _y1 = 2;
    switch (_k) {
        case "n":
            bb3d_quad(_vb, _x + _a0, _y0, _z - 1, 0, 1, _x + _a1, _y0, _z - 1, 1, 1, _x + _a1, _y1, _z - 1, 1, 0, _x + _a0, _y1, _z - 1, 0, 0, _col, _a);
            break;
        case "s":
            bb3d_quad(_vb, _x + _a1, _y0, _z + 1, 0, 1, _x + _a0, _y0, _z + 1, 1, 1, _x + _a0, _y1, _z + 1, 1, 0, _x + _a1, _y1, _z + 1, 0, 0, _col, _a);
            break;
        case "w":
            bb3d_quad(_vb, _x - 1, _y0, _z - _a0, 0, 1, _x - 1, _y0, _z - _a1, 1, 1, _x - 1, _y1, _z - _a1, 1, 0, _x - 1, _y1, _z - _a0, 0, 0, _col, _a);
            break;
        default:
            bb3d_quad(_vb, _x + 1, _y0, _z + _a0, 0, 1, _x + 1, _y0, _z + _a1, 1, 1, _x + 1, _y1, _z + _a1, 1, 0, _x + 1, _y1, _z + _a0, 0, 0, _col, _a);
            break;
    }
}

function bb3d_emit_door(_vb, _k, _x, _z, _hw, _col, _a) {
    var _y0 = 0;
    var _y1 = 2;
    switch (_k) {
        case "n":
            bb3d_quad(_vb, _x - _hw, _y0, _z - 1, 0, 1, _x + _hw, _y0, _z - 1, 1, 1, _x + _hw, _y1, _z - 1, 1, 0, _x - _hw, _y1, _z - 1, 0, 0, _col, _a);
            break;
        case "s":
            bb3d_quad(_vb, _x + _hw, _y0, _z + 1, 0, 1, _x - _hw, _y0, _z + 1, 1, 1, _x - _hw, _y1, _z + 1, 1, 0, _x + _hw, _y1, _z + 1, 0, 0, _col, _a);
            break;
        case "w":
            bb3d_quad(_vb, _x - 1, _y0, _z + _hw, 0, 1, _x - 1, _y0, _z - _hw, 1, 1, _x - 1, _y1, _z - _hw, 1, 0, _x - 1, _y1, _z + _hw, 0, 0, _col, _a);
            break;
        default:
            bb3d_quad(_vb, _x + 1, _y0, _z - _hw, 0, 1, _x + 1, _y0, _z + _hw, 1, 1, _x + 1, _y1, _z + _hw, 1, 0, _x + 1, _y1, _z - _hw, 0, 0, _col, _a);
            break;
    }
}

function bb_map_wall_has_door(_map, _q) {
    // Source mesh planes already contain the opening; never erase a whole wall.
    if (variable_struct_exists(_q, "v")) return false;
    if (!variable_struct_exists(_map, "doors")) {
        return false;
    }
    if (_q.k != "n" && _q.k != "s" && _q.k != "w" && _q.k != "e") {
        return false;
    }
    var _i;
    for (_i = 0; _i < array_length(_map.doors); _i++) {
        var _d = _map.doors[_i];
        if (abs(_d.x - _q.x) < 0.01 && abs(_d.z - _q.z) < 0.01 && _d.side == _q.k) {
            return true;
        }
        // Neighbor tile's opposite face is the same doorway in GM (no Unity parent mesh).
        var _nx = _d.x;
        var _nz = _d.z;
        var _opp = "n";
        switch (_d.side) {
            case "n": _nz -= 2; _opp = "s"; break;
            case "s": _nz += 2; _opp = "n"; break;
            case "w": _nx -= 2; _opp = "e"; break;
            default: _nx += 2; _opp = "w"; break;
        }
        if (abs(_nx - _q.x) < 0.01 && abs(_nz - _q.z) < 0.01 && _q.k == _opp) {
            return true;
        }
    }
    return false;
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
    var _school_details = !variable_struct_exists(_map, "scene") || _map.scene == "School";
    if (variable_struct_exists(_map, "materials")) {
        if (!variable_global_exists("map_textures")) global.map_textures = {};
        var _materials = variable_struct_get_names(_map.materials);
        for (var _mi = 0; _mi < array_length(_materials); _mi++) {
            var _mat = _map.materials[$ _materials[_mi]];
            if (!variable_struct_exists(global.map_textures, _mat.file)) {
                global.map_textures[$ _mat.file] = bb_load_png(_mat.file, 0, 0);
            }
        }
    }
    var _groups = {};
    var _quads = _map.quads;
    var _i;
    for (_i = 0; _i < array_length(_quads); _i++) {
        var _q = _quads[_i];
        if (_school_details && variable_struct_exists(_q, "source_id")
            && variable_struct_exists(global.P.details.dynamic_ids, _q.source_id)) continue;
        var _key = variable_struct_exists(_q, "material") ? _q.material : _q.m + (_q.d ? "_d" : "");
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
            if (bb_map_wall_has_door(_map, _qq)) {
                continue;
            }
            if (variable_struct_exists(_qq, "v")) {
                var _material = _map.materials[$ _qq.material];
                bb3d_emit_vertices(_vb, _qq.v, _material.uv, _material.colour);
            } else {
                var _col = _qq.d ? make_colour_rgb(90, 90, 90) : c_white;
                bb3d_emit_piece(_vb, _qq.k, _qq.x, _qq.z, _col, 1);
            }
        }
        vertex_end(_vb);
        vertex_freeze(_vb);
        var _batch = {
            vb: _vb,
            spr: bb3d_mat_sprite(_sample.m),
            alpha: bb3d_mat_alpha(_sample.m)
        };
        if (variable_struct_exists(_sample, "material")) {
            _batch.spr = global.map_textures[$ _map.materials[$ _sample.material].file];
            _batch.alpha = false;
        }
        if (_batch.alpha) {
            array_push(global.vb_alpha, _batch);
        } else {
            array_push(global.vb_batches, _batch);
        }
    }
}

function bb3d_sprite_uv_transform(_spr) {
    var _uv=sprite_get_uvs(_spr,0);
    return [_uv[2]-_uv[0],_uv[3]-_uv[1],_uv[0],_uv[1]];
}

function bb3d_emit_vertices(_vb, _v, _uv, _col) {
    if (array_length(_v[0]) >= 5) {
        var _order = [0, 1, 2, 0, 2, 3];
        for (var _i = 0; _i < 6; _i++) {
            var _p = _v[_order[_i]];
            bb3d_vert(_vb, _p[0], _p[1], _p[2], 0, 1, 0,
                _p[3] * _uv[0] + _uv[2], _p[4] * _uv[1] + _uv[3], _col, 1);
        }
        return;
    }
    var _u0 = _uv[2], _u1 = _u0 + _uv[0];
    var _v0 = _uv[3], _v1 = _v0 + _uv[1];
    bb3d_quad(_vb,
        _v[0][0], _v[0][1], _v[0][2], _u0, _v1,
        _v[1][0], _v[1][1], _v[1][2], _u1, _v1,
        _v[2][0], _v[2][1], _v[2][2], _u1, _v0,
        _v[3][0], _v[3][1], _v[3][2], _u0, _v0, _col, 1);
}

function bb3d_world_filter(_enabled) {
    // mip_on also covers the separate PNG textures loaded at runtime. Filtering
    // the minified world prevents distant floor/wall patterns from shimmering.
    gpu_set_texfilter(_enabled);
    gpu_set_tex_mip_enable(_enabled ? mip_on : mip_off);
    gpu_set_tex_mip_filter(_enabled ? tf_anisotropic : tf_point);
    gpu_set_tex_max_aniso(_enabled ? 8 : 1);
    gpu_set_tex_mip_bias(0);
}

function bb3d_begin(_px, _py, _pz, _yaw, _aspect, _far = 220) {
    if (!variable_global_exists("matrix_stack")) global.matrix_stack = [];
    array_push(global.matrix_stack, [matrix_get(matrix_world), matrix_get(matrix_view), matrix_get(matrix_projection)]);
    // GM 3D frame (not Unity): Y up, yaw 0 looks -Z, +X is right.
    // Projection uses -aspect because GM's perspective matrix mirrors X.
    // Map tiles are 2x2 quads; n/s/e/w are faces of that tile, not Unity transforms.
    shader_reset();
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
    gpu_set_zfunc(cmpfunc_lessequal);
    gpu_set_cullmode(cull_noculling);
    bb3d_world_filter(false);
    gpu_set_texrepeat(true);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(16);
    draw_clear(make_colour_rgb(140, 190, 230));
    var _fov = 75;
    var _proj = matrix_build_projection_perspective_fov(_fov, -_aspect, 0.08, _far);
    matrix_set(matrix_projection, _proj);
    var _fx = -sin(_yaw);
    var _fz = -cos(_yaw);
    var _view = matrix_build_lookat(_px, _py, _pz, _px + _fx, _py, _pz + _fz, 0, 1, 0);
    matrix_set(matrix_view, _view);
    matrix_set(matrix_world, matrix_build_identity());
}

function bb3d_draw_world() {
    var _i;
    bb3d_world_filter(true);
    // Imported winding preserves Unity's front faces, including mirrored scales.
    // Opposing walls may have different posters; culling avoids coplanar flicker.
    if (variable_struct_exists(global.map, "materials")) gpu_set_cullmode(cull_clockwise);
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
    gpu_set_cullmode(cull_noculling);
    bb3d_world_filter(false);
}

function bb3d_draw_char(_spr, _img, _x, _y, _z, _h, _camx, _camz, _col) {
    if (_spr < 0) {
        return;
    }
    var _sw = sprite_get_width(_spr);
    var _sh = max(1, sprite_get_height(_spr));
    var _w = _h * (_sw / _sh);
    bb3d_draw_billboard(_spr, _img, _x, _y, _z, _w, _h, _camx, _camz, _col);
}

function bb3d_draw_billboard(_spr, _img, _x, _y, _z, _w, _h, _camx, _camz, _col) {
    if (_spr < 0 || !sprite_exists(_spr)) return;
    var _uv = sprite_get_uvs(_spr, _img);
    var _dx = _camx - _x;
    var _dz = _camz - _z;
    var _len = sqrt(_dx * _dx + _dz * _dz);
    if (_len < 0.0001) {
        _len = 0.0001;
    }
    var _rx = _dz / _len;
    var _rz = -_dx / _len;
    // Atlas UVs and trimming affect both sampling and the visible part of the quad.
    var _left = -_w*0.5 + _uv[4] / sprite_get_width(_spr) * _w;
    var _right = _left + _uv[6]*_w;
    var _top = _h*0.5 - _uv[5] / sprite_get_height(_spr) * _h;
    var _bottom = _top - _uv[7]*_h;
    var _vb = global.vb_bill;
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _x+_rx*_left, _y+_bottom, _z+_rz*_left, _uv[0], _uv[3],
        _x+_rx*_right, _y+_bottom, _z+_rz*_right, _uv[2], _uv[3],
        _x+_rx*_right, _y+_top, _z+_rz*_right, _uv[2], _uv[1],
        _x+_rx*_left, _y+_top, _z+_rz*_left, _uv[0], _uv[1], _col, 1);
    vertex_end(_vb);
    gpu_set_texrepeat(false);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(32);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(_spr, _img));
    gpu_set_texrepeat(true);
}

function bb3d_deformed_vertices(_spr,_deform,_yaw) {
    var _uv=sprite_get_uvs(_spr,0),_sw=sprite_get_width(_spr),_sh=sprite_get_height(_spr);
    var _unit=_deform.units_per_pixel,_pivot=_deform.pivot;
    var _left=(-_sw*_pivot[0]+_uv[4])*_unit[0];
    var _right=_left+_uv[6]*_sw*_unit[0];
    var _top=(_sh*(1-_pivot[1])-_uv[5])*_unit[1];
    var _bottom=_top-_uv[7]*_sh*_unit[1];
    var _m=_deform.stretch,_o=_deform.origin;
    // Unity Billboard uses camera.rotation, including when looking backwards.
    // Its parent's 3/5/23 scale remains in the local-to-world transform.
    var _rx=cos(_yaw),_rz=-sin(_yaw),_right_axis=[],_up_axis=[];
    for (var _i=0;_i<3;_i++) {
        array_push(_right_axis,_m[_i][0]*_rx+_m[_i][2]*_rz);
        array_push(_up_axis,_m[_i][1]);
    }
    var _corners=[[_left,_bottom,_uv[0],_uv[3]],[_right,_bottom,_uv[2],_uv[3]],
        [_right,_top,_uv[2],_uv[1]],[_left,_top,_uv[0],_uv[1]]],_vertices=[];
    for (var _i=0;_i<4;_i++) {
        var _c=_corners[_i];
        array_push(_vertices,[_o[0]+_right_axis[0]*_c[0]+_up_axis[0]*_c[1],
            _o[1]+_right_axis[1]*_c[0]+_up_axis[1]*_c[1],
            _o[2]+_right_axis[2]*_c[0]+_up_axis[2]*_c[1],_c[2],_c[3]]);
    }
    return _vertices;
}

function bb3d_draw_deformed_billboard(_spr,_deform,_yaw) {
    var _v=bb3d_deformed_vertices(_spr,_deform,_yaw),_vb=global.vb_bill;
    vertex_begin(_vb,global.vf_3d);
    var _indices=[0,1,2,0,2,3];
    for (var _i=0;_i<6;_i++) {
        var _p=_v[_indices[_i]];
        bb3d_vert(_vb,_p[0],_p[1],_p[2],0,1,0,_p[3],_p[4],c_white,1);
    }
    vertex_end(_vb);
    gpu_set_texrepeat(false);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(32);
    vertex_submit(_vb,pr_trianglelist,sprite_get_texture(_spr,0));
    gpu_set_texrepeat(true);
}

function bb3d_end() {
    bb3d_world_filter(false);
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_cullmode(cull_noculling);
    gpu_set_alphatestenable(false);
    gpu_set_texrepeat(false);
    gpu_set_blendmode(bm_normal);
    var _saved = array_pop(global.matrix_stack);
    matrix_set(matrix_world, _saved[0]);
    matrix_set(matrix_view, _saved[1]);
    matrix_set(matrix_projection, _saved[2]);
}
