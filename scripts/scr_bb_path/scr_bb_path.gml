function bb_spatial_build() {
    if (variable_global_exists("wall_cells") && ds_exists(global.wall_cells,ds_type_map)) ds_map_destroy(global.wall_cells);
    global.wall_cells = ds_map_create();
    global.wall_seen = array_create(array_length(global.walls),0);
    global.wall_query = 0;
    for (var _i=0; _i<array_length(global.walls); _i++) {
        var _w=global.walls[_i];
        for (var _x=floor(_w.x0/4); _x<=floor(_w.x1/4); _x++) {
            for (var _z=floor(_w.z0/4); _z<=floor(_w.z1/4); _z++) {
                var _key=(_x+128)*512+_z+128;
                var _list=ds_map_find_value(global.wall_cells,_key);
                if (!is_array(_list)) _list=[];
                array_push(_list,_i); ds_map_set(global.wall_cells,_key,_list);
            }
        }
    }
}

function bb_walls_point(_x,_z,_r) {
    for (var _cx=floor((_x-_r)/4); _cx<=floor((_x+_r)/4); _cx++) {
        for (var _cz=floor((_z-_r)/4); _cz<=floor((_z+_r)/4); _cz++) {
            var _list=ds_map_find_value(global.wall_cells,(_cx+128)*512+_cz+128);
            if (!is_array(_list)) continue;
            for (var _i=0; _i<array_length(_list); _i++) {
                var _w=global.walls[_list[_i]];
                if (bb_aabb_hit(_x,_z,_r,_w.x0,_w.z0,_w.x1,_w.z1)) return true;
            }
        }
    }
    return false;
}

function bb_walls_segment(_ax,_az,_bx,_bz,_radius=0,_sight=false) {
    // Visit the ray's cells rather than sampling every 0.35 units against all walls.
    global.wall_query += 1;
    var _dx=_bx-_ax,_dz=_bz-_az;
    var _steps=max(1,ceil(max(abs(_dx),abs(_dz))/2));
    for (var _step=0; _step<=_steps; _step++) {
        var _x=lerp(_ax,_bx,_step/_steps),_z=lerp(_az,_bz,_step/_steps);
        for (var _cx=floor((_x-_radius-2)/4); _cx<=floor((_x+_radius+2)/4); _cx++) {
            for (var _cz=floor((_z-_radius-2)/4); _cz<=floor((_z+_radius+2)/4); _cz++) {
                var _list=ds_map_find_value(global.wall_cells,(_cx+128)*512+_cz+128);
                if (!is_array(_list)) continue;
                for (var _i=0; _i<array_length(_list); _i++) {
                    var _id=_list[_i];
                    if (global.wall_seen[_id] == global.wall_query) continue;
                    global.wall_seen[_id]=global.wall_query;
                    var _w=global.walls[_id];
                    if (_sight && variable_struct_exists(_w,"sight") && !_w.sight) continue;
                    if (bb_ray_box(_ax,_az,_dx,_dz,_w.x0-_radius,_w.z0-_radius,_w.x1+_radius,_w.z1+_radius) <= 1) return true;
                }
            }
        }
    }
    return false;
}

function bb_grid_id(_x,_z) {
    var _n=global.path_grid;
    var _ix=round((_x-_n.x0)*2),_iz=round((_z-_n.z0)*2);
    if (_ix<0 || _iz<0 || _ix>=_n.w || _iz>=_n.h) return -1;
    return _n.cells[_iz*_n.w+_ix];
}

function bb_grid_nearest(_x,_z) {
    var _id=bb_grid_id(_x,_z);
    if (_id>=0) return _id;
    var _best=-1,_dd=1000000,_n=global.path_grid;
    for (var _r=1; _r<=6; _r++) {
        for (var _ix=-_r; _ix<=_r; _ix++) {
            for (var _iz=-_r; _iz<=_r; _iz++) {
                if (abs(_ix)!=_r && abs(_iz)!=_r) continue;
                var _node=bb_grid_id(_x+_ix*.5,_z+_iz*.5);
                if (_node<0) continue;
                var _d=bb_dist2(_x,_z,_n.xs[_node],_n.zs[_node]);
                if (_d<_dd) { _dd=_d; _best=_node; }
            }
        }
        if (_best>=0) return _best;
    }
    return -1;
}

function bb_grid_node_reachable(_x,_z,_id,_r) {
    if (_id<0) return false;
    var _n=global.path_grid,_tx=_n.xs[_id],_tz=_n.zs[_id];
    if (bb_dist2(_x,_z,_tx,_tz)<.000001) return !bb_blocked_world(_x,_z,_r,true);
    var _p=bb_move_slide(_x,_z,_tx-_x,_tz-_z,_r,true);
    return bb_dist2(_p[0],_p[1],_tx,_tz)<.0001;
}

function bb_grid_start(_x,_z,_r=.3) {
    var _n=global.path_grid,_nearest=bb_grid_nearest(_x,_z);
    if (bb_grid_node_reachable(_x,_z,_nearest,_r)) return _nearest;
    var _base_x=round((_x-_n.x0)*2),_base_z=round((_z-_n.z0)*2);
    for (var _ring=1;_ring<=8;_ring++) {
        var _best=-1,_best_d=1000000;
        for (var _ox=-_ring;_ox<=_ring;_ox++) {
            for (var _oz=-_ring;_oz<=_ring;_oz++) {
                if (abs(_ox)!=_ring && abs(_oz)!=_ring) continue;
                var _ix=_base_x+_ox,_iz=_base_z+_oz;
                if (_ix<0 || _iz<0 || _ix>=_n.w || _iz>=_n.h) continue;
                var _id=_n.cells[_iz*_n.w+_ix];
                if (_id<0 || !bb_grid_node_reachable(_x,_z,_id,_r)) continue;
                var _d=bb_dist2(_x,_z,_n.xs[_id],_n.zs[_id])+_n.center[_id]*.001;
                if (_d<_best_d) {_best_d=_d;_best=_id;}
            }
        }
        if (_best>=0) return _best;
    }
    return _nearest;
}

function bb_grid_recover_position(_x,_z,_r=.3) {
    if (!bb_blocked_world(_x,_z,_r,true)) return [_x,_z];
    var _n=global.path_grid,_base_x=round((_x-_n.x0)*2),_base_z=round((_z-_n.z0)*2);
    for (var _ring=0;_ring<=12;_ring++) {
        var _best=-1,_best_d=1000000;
        for (var _ox=-_ring;_ox<=_ring;_ox++) {
            for (var _oz=-_ring;_oz<=_ring;_oz++) {
                if (_ring>0 && abs(_ox)!=_ring && abs(_oz)!=_ring) continue;
                var _ix=_base_x+_ox,_iz=_base_z+_oz;
                if (_ix<0 || _iz<0 || _ix>=_n.w || _iz>=_n.h) continue;
                var _id=_n.cells[_iz*_n.w+_ix];
                if (_id<0) continue;
                // A tiny probe rejects candidates across a real wall while still
                // allowing an authored spawn that only overlaps the actor-radius margin.
                var _tx=_n.xs[_id],_tz=_n.zs[_id];
                var _probe=bb_move_slide(_x,_z,_tx-_x,_tz-_z,.01,true);
                if (bb_dist2(_probe[0],_probe[1],_tx,_tz)>=.0001) continue;
                var _d=bb_dist2(_x,_z,_tx,_tz)+_n.center[_id]*.001;
                if (_d<_best_d) {_best_d=_d;_best=_id;}
            }
        }
        if (_best>=0) return [_n.xs[_best],_n.zs[_best]];
    }
    var _fallback=bb_grid_nearest(_x,_z);
    return (_fallback>=0)?[_n.xs[_fallback],_n.zs[_fallback]]:[_x,_z];
}

function bb_grid_build() {
    var _keys=ds_map_keys_to_array(global.floors);
    var _x0=1000,_z0=1000,_x1=-1000,_z1=-1000;
    for (var _i=0; _i<array_length(_keys); _i++) {
        var _p=string_split(_keys[_i],",");var _x=real(_p[0]),_z=real(_p[1]);
        _x0=min(_x0,_x-1);_x1=max(_x1,_x+1);_z0=min(_z0,_z-1);_z1=max(_z1,_z+1);
    }
    var _w=round((_x1-_x0)*2)+1,_h=round((_z1-_z0)*2)+1;
    global.path_grid={x0:_x0,z0:_z0,w:_w,h:_h,cells:array_create(_w*_h,-1),xs:[],zs:[],neighbors:[],door:[],center:[],routes:[],mask:-1,searches:0};
    var _n=global.path_grid;
    for (var _iz=0; _iz<_h; _iz++) {
        for (var _ix=0; _ix<_w; _ix++) {
            var _x=_x0+_ix*.5,_z=_z0+_iz*.5;
            if (!bb_on_floor(_x,_z) || bb_walls_point(_x,_z,.3)) continue;
            var _id=array_length(_n.xs);
            _n.cells[_iz*_w+_ix]=_id;array_push(_n.xs,_x);array_push(_n.zs,_z);array_push(_n.neighbors,[]);
            array_push(_n.center,min(abs(_x-bb_tile_snap(_x)),abs(_z-bb_tile_snap(_z))));
            var _door=-1;
            for (var _di=0; _di<array_length(global.G.doors); _di++) {
                var _box=bb_door_box(global.G.doors[_di]);
                if (bb_aabb_hit(_x,_z,.3,_box[0],_box[1],_box[2],_box[3])) { _door=_di;break; }
            }
            array_push(_n.door,_door);
        }
    }
    // Actors use the floor-center lattice and take axis-aligned turns. This
    // prevents a diagonal corner cut from entering furniture colliders.
    var _dirs=[[.5,0],[-.5,0],[0,.5],[0,-.5]];
    for (var _id=0; _id<array_length(_n.xs); _id++) {
        var _x=_n.xs[_id],_z=_n.zs[_id],_links=[];
        for (var _i=0; _i<4; _i++) {
            var _dx=_dirs[_i][0],_dz=_dirs[_i][1],_nb=bb_grid_id(_x+_dx,_z+_dz);
            if (_nb<0) continue;
            if (!bb_walls_segment(_x,_z,_x+_dx,_z+_dz,.29)) array_push(_links,_nb);
        }
        // Equal-cost expansion inherits this one-time center ordering.
        for (var _a=0; _a<array_length(_links); _a++) {
            for (var _b=_a+1; _b<array_length(_links); _b++) {
                if (_n.center[_links[_b]]<_n.center[_links[_a]]) {
                    var _swap=_links[_a];_links[_a]=_links[_b];_links[_b]=_swap;
                }
            }
        }
        _n.neighbors[_id]=_links;
    }
    global.path_grids[$ string(global.path_signature)] = _n;
}

function bb_grid_step(_x,_z,_tx,_tz,_r=.3) {
    var _n=global.path_grid,_start=bb_grid_start(_x,_z,_r),_goal=bb_grid_start(_tx,_tz,_r);
    if (_start<0 || _goal<0) return [_x,_z];
    if (_start==_goal) {
        if (!bb_blocked_world(_tx,_tz,_r,true)) {
            var _direct=bb_move_slide(_x,_z,_tx-_x,_tz-_z,_r,true);
            if (bb_dist2(_direct[0],_direct[1],_tx,_tz)<.0001) return [_tx,_tz];
        }
        return [_n.xs[_goal],_n.zs[_goal]];
    }
    var _mask=0;
    for (var _i=0; _i<array_length(global.G.doors); _i++) {
        var _d=global.G.doors[_i];
        if (_d.locked || _d.lock_cd>0) _mask |= (1<<_i);
    }
    if (_mask!=_n.mask) { _n.mask=_mask; _n.routes=[]; }
    var _next=undefined,_route_index=-1;
    for (var _i=0; _i<array_length(_n.routes); _i++) {
        if (_n.routes[_i].goal!=_goal) continue;
        _route_index=_i;
        if (_n.routes[_i].settled[_start]) {_next=_n.routes[_i].next;break;}
    }
    if (is_undefined(_next)) {
        _n.searches+=1;
        var _count=array_length(_n.xs);
        _next=array_create(_count,-1);
        var _settled=array_create(_count,false);
        var _distance=array_create(_count,1000000000);
        var _buckets=[[],[],[],[],[],[]],_heads=array_create(6,0);
        var _pending=1,_current_cost=0;
        _distance[_goal]=0;_next[_goal]=_goal;
        array_push(_buckets[0],_goal);
        while (_pending>0) {
            var _bucket_id=_current_cost mod 6,_bucket=_buckets[_bucket_id],_head=_heads[_bucket_id];
            if (_head>=array_length(_bucket)) {_current_cost+=1;continue;}
            var _packed=_bucket[_head],_cost=floor(_packed/_count);
            if (_cost>_current_cost) {_current_cost+=1;continue;}
            _heads[_bucket_id]=_head+1;_pending-=1;
            var _cur=_packed mod _count;
            if (_cost!=_distance[_cur]) continue;
            _settled[_cur]=true;
            if (_cur==_start) break;
            var _neighbors=_n.neighbors[_cur];
            for (var _i=0; _i<array_length(_neighbors); _i++) {
                var _nb=_neighbors[_i];
                var _door=_n.door[_nb];
                if (_door>=0 && (_mask & (1<<_door))!=0) continue;
                // Center nodes cost 1. Half- and full-unit offsets cost 3 and
                // 5, so a short safe detour is preferred over wall-hugging.
                var _new_cost=_cost+1+round(_n.center[_cur]*4);
                if (_new_cost<_distance[_nb]) {
                    _distance[_nb]=_new_cost;_next[_nb]=_cur;
                    array_push(_buckets[_new_cost mod 6],_new_cost*_count+_nb);_pending+=1;
                } else if (_new_cost==_distance[_nb] && _n.center[_cur]<_n.center[_next[_nb]]) {
                    _next[_nb]=_cur;
                }
            }
        }
        if (_route_index>=0) _n.routes[_route_index]={goal:_goal,next:_next,settled:_settled};
        else {
            if (array_length(_n.routes)>=32) array_delete(_n.routes,0,1);
            array_push(_n.routes,{goal:_goal,next:_next,settled:_settled});
        }
    }
    var _id=_next[_start];
    if (_id<0) return [_x,_z];
    var _wx=_n.xs[_id],_wz=_n.zs[_id];
    var _sx=_n.xs[_start],_sz=_n.zs[_start],_projection=undefined;
    // Continuous actor positions can be off the discrete route after spawn,
    // collision or BSODA. Enter the current weighted path edge laterally
    // before advancing along it, rather than cutting diagonally to its end.
    if (abs(_wx-_sx)<.001 && abs(_x-_sx)>.04) {
        _projection=[_sx,clamp(_z,min(_sz,_wz),max(_sz,_wz))];
    } else if (abs(_wz-_sz)<.001 && abs(_z-_sz)>.04) {
        _projection=[clamp(_x,min(_sx,_wx),max(_sx,_wx)),_sz];
    }
    if (!is_undefined(_projection)
        && !bb_blocked_world(_projection[0],_projection[1],.3,true)
        && !bb_walls_segment(_x,_z,_projection[0],_projection[1],.29)) return _projection;
    if (bb_walls_segment(_x,_z,_wx,_wz,.29)) return [_n.xs[_start],_n.zs[_start]];
    return [_wx,_wz];
}
