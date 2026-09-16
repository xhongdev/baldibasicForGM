function bb_nav_build() {
    if (variable_global_exists("nav_n") && ds_exists(global.nav_n, ds_type_map)) {
        ds_map_destroy(global.nav_n);
    }
    global.nav_n = ds_map_create();
    if (variable_global_exists("nav_portals") && ds_exists(global.nav_portals, ds_type_map)) {
        ds_map_destroy(global.nav_portals);
    }
    global.nav_portals = ds_map_create();
    global.nav_portal_points = [];
    var _keys = ds_map_keys_to_array(global.floors);
    if (variable_struct_exists(global.map, "nav_edges")) {
        for (var _i = 0; _i < array_length(_keys); _i++) ds_map_set(global.nav_n, _keys[_i], []);
        for (var _i = 0; _i < array_length(global.map.nav_edges); _i++) {
            var _e = global.map.nav_edges[_i];
            var _a = bb_key(_e.a[0], _e.a[1]), _b = bb_key(_e.b[0], _e.b[1]);
            var _an = ds_map_find_value(global.nav_n, _a), _bn = ds_map_find_value(global.nav_n, _b);
            array_push(_an, _b);
            array_push(_bn, _a);
            ds_map_set(global.nav_n, _a, _an);
            ds_map_set(global.nav_n, _b, _bn);
            ds_map_set(global.nav_portals, _a + "|" + _b, _e.p);
            ds_map_set(global.nav_portals, _b + "|" + _a, _e.p);
            var _known=false;
            for (var _pi=0;_pi<array_length(global.nav_portal_points);_pi++) {
                if (bb_dist2(global.nav_portal_points[_pi][0],global.nav_portal_points[_pi][1],_e.p[0],_e.p[1])<.0001) {_known=true;break;}
            }
            if (!_known) array_push(global.nav_portal_points,_e.p);
        }
        return;
    }
    var _i;
    var _dirs = [[2, 0, "e", "w"], [-2, 0, "w", "e"], [0, 2, "s", "n"], [0, -2, "n", "s"]];
    for (_i = 0; _i < array_length(_keys); _i++) {
        var _k = _keys[_i];
        var _p = string_split(_k, ",");
        var _x = real(_p[0]);
        var _z = real(_p[1]);
        var _nb = [];
        var _d;
        for (_d = 0; _d < 4; _d++) {
            var _nx = _x + _dirs[_d][0];
            var _nz = _z + _dirs[_d][1];
            var _nk = bb_key(_nx, _nz);
            if (!ds_map_exists(global.floors, _nk)) {
                continue;
            }
            if (bb_edge_solid(_x, _z, _dirs[_d][2]) || bb_edge_solid(_nx, _nz, _dirs[_d][3])) {
                continue;
            }
            array_push(_nb, _nk);
        }
        ds_map_set(global.nav_n, _k, _nb);
    }
}

function bb_edge_solid(_x, _z, _side) {
    if (!variable_global_exists("wall_edge") || !ds_exists(global.wall_edge, ds_type_map)) {
        return false;
    }
    return ds_map_exists(global.wall_edge, bb_key(_x, _z) + "," + _side);
}

function bb_tile_snap(_v) {
    return round(_v / 2) * 2;
}

function bb_nav_nearest(_sx, _sz) {
    var _sk = bb_key(bb_tile_snap(_sx), bb_tile_snap(_sz));
    if (ds_map_exists(global.nav_n, _sk)) {
        return _sk;
    }
    var _best = "";
    var _best_d = 100000;
    var _keys = ds_map_keys_to_array(global.nav_n);
    var _i;
    for (_i = 0; _i < array_length(_keys); _i++) {
        var _p = string_split(_keys[_i], ",");
        var _dx = real(_p[0]) - _sx;
        var _dz = real(_p[1]) - _sz;
        var _d = _dx * _dx + _dz * _dz;
        if (_d < _best_d) {
            _best_d = _d;
            _best = _keys[_i];
        }
    }
    return _best;
}

function bb_nav_step(_sx, _sz, _gx, _gz, _r=.3) {
    return bb_grid_step(_sx, _sz, _gx, _gz, _r);
}

function bb_nav_corridor(_x, _z) {
    var _key = bb_nav_nearest(_x, _z);
    if (_key == "") return [0, _x, _z];
    var _center = string_split(_key, ","), _cx = real(_center[0]), _cz = real(_center[1]);
    var _neighbors = ds_map_find_value(global.nav_n, _key);
    var _horizontal = false, _vertical = false;
    for (var _i=0; _i<array_length(_neighbors); _i++) {
        var _p = string_split(_neighbors[_i], ",");
        if (abs(real(_p[0])-_cx) > .1) _horizontal = true;
        if (abs(real(_p[1])-_cz) > .1) _vertical = true;
    }
    if (_vertical && !_horizontal) return [1, _cx, _cz];
    if (_horizontal && !_vertical) return [2, _cx, _cz];
    return [0, _cx, _cz];
}

function bb_nav_portal_nearest(_x,_z,_tx,_tz) {
    var _keys=ds_map_keys_to_array(global.nav_n),_best="",_score=1000000000;
    for (var _i=0;_i<array_length(_keys);_i++) {
        var _p=string_split(_keys[_i],",");
        var _d=bb_dist2(_x,_z,real(_p[0]),real(_p[1]));
        // A target-directed tie break selects the tile beyond a portal as
        // soon as the actor reaches its center instead of turning back.
        var _td=bb_dist2(_tx,_tz,real(_p[0]),real(_p[1]));
        var _value=_d+0.0001*_td;
        if (_value<_score) {_score=_value;_best=_keys[_i];}
    }
    return _best;
}

function bb_nav_portal_open(_p,_mask) {
    for (var _i=0;_i<array_length(global.G.doors);_i++) {
        var _d=global.G.doors[_i];
        if (bb_door_touching(_d,_p[0],_p[1],.12) && (_mask & (1<<_i))!=0) return false;
    }
    return true;
}

function bb_nav_portal_step(_sx,_sz,_gx,_gz) {
    var _start=bb_nav_portal_nearest(_sx,_sz,_gx,_gz);
    var _goal=bb_nav_portal_nearest(_gx,_gz,_gx,_gz);
    if (_start=="" || _goal=="") return [_sx,_sz];
    var _sp=string_split(_start,","),_center_x=real(_sp[0]),_center_z=real(_sp[1]);
    var _near_portal=false;
    for (var _pi=0;_pi<array_length(global.nav_portal_points);_pi++) {
        var _pp=global.nav_portal_points[_pi];
        if (bb_dist2(_sx,_sz,_pp[0],_pp[1])<.08) {_near_portal=true;break;}
    }
    if (!_near_portal) {
        for (var _pi=0;_pi<array_length(global.nav_portal_points);_pi++) {
            var _pp=global.nav_portal_points[_pi],_dx=abs(_sx-_pp[0]),_dz=abs(_sz-_pp[1]);
            if ((_dx<.06 && _dz>.35 && _dz<1.05) || (_dz<.06 && _dx>.35 && _dx<1.05)) return _pp;
        }
    }
    // NPCs leave a spawn or an interrupted slide by first returning to the
    // authored floor center.  Only a real doorway portal permits an offset.
    if (!_near_portal && bb_dist2(_sx,_sz,_center_x,_center_z)>.06) return [_center_x,_center_z];
    if (_near_portal) return [_center_x,_center_z];
    if (_start==_goal) return [_gx,_gz];
    var _mask=0;
    for (var _i=0;_i<array_length(global.G.doors);_i++) {
        if (global.G.doors[_i].locked || global.G.doors[_i].lock_cd>0) _mask|=(1<<_i);
    }
    if (!variable_global_exists("nav_routes") || !is_array(global.nav_routes)) global.nav_routes=[];
    var _next=undefined;
    for (var _ri=0;_ri<array_length(global.nav_routes);_ri++) {
        var _route=global.nav_routes[_ri];
        if (_route.goal==_goal && _route.mask==_mask) {_next=_route.next;break;}
    }
    if (is_undefined(_next)) {
        _next={};
        var _queue=[_goal],_head=0,_seen={};
        variable_struct_set(_seen,_goal,true);
        while (_head<array_length(_queue)) {
            var _cur=_queue[_head++],_nbs=ds_map_find_value(global.nav_n,_cur);
            for (var _ni=0;_ni<array_length(_nbs);_ni++) {
                var _nb=_nbs[_ni],_p=ds_map_find_value(global.nav_portals,_cur+"|"+_nb);
                if (is_undefined(_p) || !bb_nav_portal_open(_p,_mask) || variable_struct_exists(_seen,_nb)) continue;
                variable_struct_set(_seen,_nb,true);variable_struct_set(_next,_nb,_cur);array_push(_queue,_nb);
            }
        }
        array_push(global.nav_routes,{goal:_goal,mask:_mask,next:_next});
        if (array_length(global.nav_routes)>32) array_delete(global.nav_routes,0,1);
    }
    if (!variable_struct_exists(_next,_start)) return [_sx,_sz];
    var _to=variable_struct_get(_next,_start),_portal=ds_map_find_value(global.nav_portals,_start+"|"+_to);
    if (!is_undefined(_portal)) {
        // Offset classroom/faculty doors need an axis-aligned approach. A
        // diagonal from a tile center can clip a jamb even when the portal is
        // open, so insert the clear elbow before entering the doorway.
        var _cx=real(_sp[0]),_cz=real(_sp[1]);
        if (abs(_cx-_portal[0])>.06 && abs(_cz-_portal[1])>.06) {
            var _elbows=[[ _cx,_portal[1] ],[ _portal[0],_cz ]];
            for (var _ei=0;_ei<2;_ei++) {
                var _ex=_elbows[_ei][0],_ez=_elbows[_ei][1];
                if (bb_on_floor(_ex,_ez) && !bb_blocked_world(_ex,_ez,.29,true)) return [_ex,_ez];
            }
        }
        return _portal;
    }
    var _p=string_split(_to,",");return [real(_p[0]),real(_p[1])];
}

function bb_blocked_world(_px, _pz, _r, _doors_block) {
    var _i;
    if (bb_walls_point(_px,_pz,_r)) return true;
    // All actors collide with jambs and locked doors. NPCs may open unlocked doors.
    {
        var _g = global.G;
        for (_i = 0; _i < array_length(_g.doors); _i++) {
            var _d = _g.doors[_i];
            if (_d.kind == "swing") {
                if (!_d.locked) {
                    continue;
                }
                var _box = bb_door_box(_d);
                if (bb_aabb_hit(_px, _pz, _r, _box[0], _box[1], _box[2], _box[3])) {
                    return true;
                }
            } else {
                if (!variable_struct_exists(_d, "v")) {
                    var _j0 = bb_door_jamb_box(_d, -1);
                    var _j1 = bb_door_jamb_box(_d, 1);
                    if (bb_aabb_hit(_px, _pz, _r, _j0[0], _j0[1], _j0[2], _j0[3])) return true;
                    if (bb_aabb_hit(_px, _pz, _r, _j1[0], _j1[1], _j1[2], _j1[3])) return true;
                }
                if (!_d.open && (_doors_block || _d.locked || _d.lock_cd > 0)) {
                    var _box2 = bb_door_box(_d);
                    if (bb_aabb_hit(_px, _pz, _r, _box2[0], _box2[1], _box2[2], _box2[3])) {
                        return true;
                    }
                }
            }
        }
    }
    if (!bb_on_floor(_px, _pz)) {
        return true;
    }
    return false;
}

function bb_move_slide(_x, _z, _dx, _dz, _r, _doors_block) {
    if (is_nan(_dx) || is_nan(_dz) || is_infinity(_dx) || is_infinity(_dz)) return [_x, _z];
    var _step = 0.08;
    var _len = sqrt(_dx * _dx + _dz * _dz);
    if (_len < 0.0001) {
        return [_x, _z];
    }
    var _left = _len;
    var _ux = _dx / _len;
    var _uz = _dz / _len;
    while (_left > 0.0001) {
        var _use = min(_step, _left);
        var _nx = _x + _ux * _use;
        var _nz = _z + _uz * _use;
        if (!bb_blocked_world(_nx, _nz, _r, _doors_block)) {
            _x = _nx;
            _z = _nz;
            _left -= _use;
            continue;
        }
        if (!bb_blocked_world(_x + _ux * _use, _z, _r, _doors_block)) {
            _x += _ux * _use;
            _left -= _use;
            continue;
        }
        if (!bb_blocked_world(_x, _z + _uz * _use, _r, _doors_block)) {
            _z += _uz * _use;
            _left -= _use;
            continue;
        }
        break;
    }
    return [_x, _z];
}

function bb_nav_advance(_x, _z, _tx, _tz, _dist, _r, _doors_block) {
    var _remain = _dist;
    var _guard = 0;
    while (_remain > 0.00001 && _guard < 24) {
        _guard += 1;
        var _wp=bb_grid_step(_x,_z,_tx,_tz,_r);
        var _dx = _wp[0] - _x;
        var _dz = _wp[1] - _z;
        if (is_nan(_dx) || is_nan(_dz) || is_infinity(_dx) || is_infinity(_dz)) break;
        var _len = sqrt(_dx * _dx + _dz * _dz);
        // GM's comparison epsilon can make 0 < 0.00001 false. Include equality
        // so arrival never normalizes a zero direction into 0/0 (NaN).
        if (_len <= 0.00001) {
            break;
        }
        var _use = min(_remain, _len);
        if (_doors_block) bb_npc_open_path_doors(_x, _z, _wp[0], _wp[1], _r);
        var _sl = bb_move_slide(_x, _z, (_dx / _len) * _use, (_dz / _len) * _use, _r, _doors_block);
        var _moved = sqrt(sqr(_sl[0] - _x) + sqr(_sl[1] - _z));
        _x = _sl[0];
        _z = _sl[1];
        if (_moved <= 0.00001) {
            break;
        }
        _remain -= _moved;
    }
    return [_x, _z];
}

function bb_npc_open_path_doors(_x, _z, _tx, _tz, _r) {
    var _dx = _tx-_x, _dz = _tz-_z;
    if (abs(_dx)+abs(_dz) <= 0.000001) return;
    for (var _i=0; _i<array_length(global.G.doors); _i++) {
        var _d = global.G.doors[_i];
        if (_d.open) continue;
        var _b = bb_door_box(_d), _padding = _r+0.16;
        if (bb_ray_box(_x, _z, _dx, _dz, _b[0]-_padding, _b[1]-_padding,
            _b[2]+_padding, _b[3]+_padding) <= 1) {
            bb_door_try_open(_d, false);
        }
    }
}

function bb_los(_ax, _az, _bx, _bz) {
    if (bb_walls_segment(_ax,_az,_bx,_bz,0,true)) return false;
    for (var _i=0; _i<array_length(global.G.doors); _i++) {
        var _d=global.G.doors[_i];
        if (_d.open || _d.kind=="swing") continue;
        var _b=bb_door_box(_d);
        if (bb_ray_box(_ax,_az,_bx-_ax,_bz-_az,_b[0],_b[1],_b[2],_b[3])<=1) return false;
    }
    return true;
}

function bb_los_door_block(_x, _z) {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (_d.open || _d.kind == "swing") {
            continue;
        }
        var _box = bb_door_box(_d);
        if (bb_aabb_hit(_x, _z, 0.08, _box[0], _box[1], _box[2], _box[3])) {
            return true;
        }
    }
    return false;
}

function bb_baldi_recalc_wait() {
    var _g = global.G;
    var _a = _g.baldi_anger;
    if (_a < 0.5) {
        _a = 0.5;
        _g.baldi_anger = 0.5;
    }
    _g.baldi_wait = -3 * _a / (_a + 2 / global.E.baldi.baldiSpeedScale) + 3;
}

function bb_get_angry(_value) {
    var _g = global.G;
    if (!_g.spoop_mode) {
        bb_activate_spoop();
    }
    _g.baldi_anger += _value;
    bb_baldi_recalc_wait();
}

function bb_get_temp_angry(_value) {
    global.G.baldi_extra += _value;
}

function bb_hear(_x, _z) {
    bb_hear_pri(_x, _z, 1);
}

function bb_hear_pri(_x, _z, _pri) {
    var _g = global.G;
    if (_g.anti_hear <= 0 && _pri >= _g.hear_pri) {
        _g.hear_x = _x;
        _g.hear_z = _z;
        _g.hear_pri = _pri;
    }
}

function bb_update_baldi(_dt) {
    var _g = global.G;
    if (!_g.baldi_active || _g.state != "play" || _g.debug.freeze_baldi) {
        return;
    }
    if (_g.mode == "endless") {
        _g.anger_time -= _dt;
        while (_g.anger_time <= 0) {
            _g.anger_time += global.E.baldi.angerFrequency;
            _g.baldi_anger += _g.anger_rate;
            _g.anger_rate += global.E.baldi.angerRateRate;
            bb_baldi_recalc_wait();
        }
    }
    if (_g.baldi_sprayed) {
        _g.baldi_move = 0;
        _g.baldi_cd = max(0.2, _g.baldi_cd - _dt);
        return;
    }
    if (_g.baldi_extra > 0) {
        _g.baldi_extra = max(0, _g.baldi_extra - 0.02 * _dt);
    } else {
        _g.baldi_extra = 0;
    }
    if (_g.baldi_cool > 0) {
        _g.baldi_cool -= _dt;
    }
    if (bb_los(_g.baldi_x, _g.baldi_z, _g.px, _g.pz)) {
        _g.hear_x = _g.px;
        _g.hear_z = _g.pz;
        _g.hear_pri = 0;
        _g.baldi_cool = 1;
    }
    if (_g.baldi_move > 0) {
        var _move_dt = min(_dt, _g.baldi_move);
        _g.baldi_move -= _move_dt;
        bb_npc_touch_doors(_g.baldi_x, _g.baldi_z, 0.4);
        var _pos = bb_nav_advance(_g.baldi_x, _g.baldi_z, _g.hear_x, _g.hear_z,
            15 * _move_dt, 0.28, true);
        var _spray = bb_spray_contact(_g.baldi_x, _g.baldi_z, _pos[0], _pos[1], 1.28);
        if (_spray != -1) {
            bb_soda_push_baldi(_g.sprays[_spray], _dt);
            _g.baldi_move = 0;
            return;
        }
        _g.baldi_x = _pos[0];
        _g.baldi_z = _pos[1];
        bb_npc_touch_doors(_g.baldi_x, _g.baldi_z, 0.4);
    }
    if (_g.baldi_cd > 0) {
        _g.baldi_cd -= _dt;
    } else {
        if (bb_dist2(_g.baldi_x, _g.baldi_z, _g.baldi_prev_x, _g.baldi_prev_z) < 0.04 && _g.baldi_cool <= 0) {
            bb_baldi_wander();
            _g.hear_pri = 0;
        }
        bb_world_sound(snd_bal_slap, _g.baldi_x, _g.baldi_z, 3, 100);
        _g.baldi_frame = 0;
        _g.baldi_move = 0.2;
        _g.baldi_cd = max(0.2, _g.baldi_wait - _g.baldi_extra);
        _g.baldi_prev_x = _g.baldi_x;
        _g.baldi_prev_z = _g.baldi_z;
    }
    _g.baldi_frame = min(4, _g.baldi_frame + 18 * _dt);
    if (bb_dist2(_g.px, _g.pz, _g.baldi_x, _g.baldi_z) < 0.7 * 0.7) {
        bb_gameover();
    }
}

function bb_baldi_wander() {
    var _g = global.G;
    var _keys = ds_map_keys_to_array(global.floors);
    if (array_length(_keys) == 0) {
        return;
    }
    var _k = _keys[irandom(array_length(_keys) - 1)];
    var _p = string_split(_k, ",");
    _g.hear_x = real(_p[0]);
    _g.hear_z = real(_p[1]);
}

function bb_npc_touch_doors(_x, _z, _r) {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (bb_door_touching(_d, _x, _z, _r)) {
            bb_door_try_open(_d, false);
        }
    }
}

function bb_walk_nav_end(_x, _z, _dx, _dz) {
    var _k = bb_nav_nearest(_x, _z);
    if (_k == "") {
        return [_x, _z];
    }
    var _guard = 0;
    while (_guard < 80) {
        _guard += 1;
        var _p = string_split(_k, ",");
        var _cx = real(_p[0]);
        var _cz = real(_p[1]);
        var _nk = bb_key(_cx + _dx, _cz + _dz);
        var _nbs = ds_map_find_value(global.nav_n, _k);
        var _ok = false;
        if (is_array(_nbs)) {
            var _i;
            for (_i = 0; _i < array_length(_nbs); _i++) {
                if (_nbs[_i] == _nk) {
                    _ok = true;
                    break;
                }
            }
        }
        if (!_ok) {
            return [_cx, _cz];
        }
        _k = _nk;
    }
    var _p2 = string_split(_k, ",");
    return [real(_p2[0]), real(_p2[1])];
}

function bb_baldi_chase_spawn() {
    var _g = global.G;
    var _ax = _g.tutor_x - _g.px;
    var _az = _g.tutor_z - _g.pz;
    var _card = [[2, 0], [-2, 0], [0, 2], [0, -2]];
    var _best = 0;
    var _best_d = -100000;
    var _i;
    for (_i = 0; _i < 4; _i++) {
        var _dot = _card[_i][0] * _ax + _card[_i][1] * _az;
        if (_dot > _best_d) {
            _best_d = _dot;
            _best = _i;
        }
    }
    var _end = bb_walk_nav_end(_g.tutor_x, _g.tutor_z, _card[_best][0], _card[_best][1]);
    if (bb_dist2(_end[0], _end[1], _g.tutor_x, _g.tutor_z) < 8) {
        var _far = _end;
        var _far_d = -1;
        for (_i = 0; _i < 4; _i++) {
            var _e2 = bb_walk_nav_end(_g.tutor_x, _g.tutor_z, _card[_i][0], _card[_i][1]);
            if (bb_dist2(_e2[0], _e2[1], _g.px, _g.pz) < 9) {
                continue;
            }
            var _td = bb_dist2(_e2[0], _e2[1], _g.tutor_x, _g.tutor_z);
            if (_td > _far_d) {
                _far_d = _td;
                _far = _e2;
            }
        }
        _end = _far;
    }
    return _end;
}
