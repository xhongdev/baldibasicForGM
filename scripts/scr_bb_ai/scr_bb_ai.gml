function bb_ai_init(_n) {
    var _s=global.E.npcs[$ _n.kind];
    _n.source=_s;_n.x=_s.spawn[0];_n.z=_s.spawn[1];_n.home_x=_n.x;_n.home_z=_n.z;
    _n.y=_s.y;_n.w=_s.w;_n.h=_s.h;_n.spr=global.PS[$ _s.texture];
    _n.visible=(_n.kind!="bully" && _n.kind!="crafters");
    _n.mode=(_n.kind=="bully")?"hidden":((_n.kind=="sweep")?"rest":"wander");
    _n.mode_time=(_n.kind=="bully")?random_range(60,120):random_range(120,180);
    _n.target_x=_n.x;_n.target_z=_n.z;_n.target_ready=false;
    _n.wander_cool=0;_n.stuck=0;_n.vx=0;_n.vz=0;_n.sense_time=random(.05);_n.sees=false;
    _n.wanders=0;_n.active_time=0;_n.guilt=0;_n.spoken=false;_n.touch=false;_n.force_show=0;_n.sound=-1;
    _n.player_seen=false;_n.hug_announced=false;_n.bully_seen=false;
}

function bb_ai_sound(_n,_name,_replace=false,_index=-1) {
    if (!variable_struct_exists(_n.source.audio,_name)) return -1;
    if (_n.sound!=-1 && audio_is_playing(_n.sound)) {
        if (!_replace) return _n.sound;
        audio_stop_sound(_n.sound);
    }
    var _clip=_n.source.audio[$ _name];
    if (is_array(_clip)) _clip=_clip[(_index<0)?irandom(array_length(_clip)-1):clamp(_index,0,array_length(_clip)-1)];
    _n.sound=bb_world_sound(global.S.clips[$ _clip],_n.x,_n.z,2,24);
    return _n.sound;
}

function bb_ai_target(_n,_hallway=true) {
    var _targets=global.E.targets,_count=min(array_length(_targets),_hallway?16:29);
    for (var _try=0; _try<24; _try++) {
        var _p=_targets[irandom(_count-1)];
        if (bb_dist2(_n.x,_n.z,_p[0],_p[2])<4) continue;
        _n.target_x=_p[0];_n.target_z=_p[2];_n.target_ready=true;break;
    }
    _n.wander_cool=1;_n.stuck=0;
    if (_n.kind=="playtime") bb_ai_sound(_n,"aud_Random");
    if (_n.kind=="principal" && irandom(9)==0) bb_ai_sound(_n,"aud_Whistle");
    if (_n.kind=="prize") {
        _n.hug_announced=false;
        if (irandom(9)==0) bb_ai_sound(_n,"aud_Random");
    }
}

function bb_ai_go(_n,_tx,_tz,_speed,_dt) {
    var _x=_n.x,_z=_n.z;
    // The principal's office exit must not unlock or visually open the blue
    // detention door. Only his movement ignores that barrier while it is locked.
    var _ignore_door=-1;
    if (_n.kind=="principal" && global.G.detention>0) {
        var _office=bb_office_door();
        if (_office>=0 && global.G.doors[_office].locked) _ignore_door=_office;
    }
    if (bb_blocked_world(_x,_z,.3,true,_ignore_door)) {
        var _recovered=bb_grid_recover_position(_x,_z,.3,_ignore_door);
        _x=_recovered[0];_z=_recovered[1];_n.x=_x;_n.z=_z;
    }
    bb_npc_touch_doors(_x,_z,.4);
    var _p=bb_nav_advance(_x,_z,_tx,_tz,_speed*_dt,.3,true,_ignore_door);
    _n.x=_p[0];_n.z=_p[1];
    _n.vx=(_n.x-_x)/max(_dt,.0001);_n.vz=(_n.z-_z)/max(_dt,.0001);
    // Include equality: GM's comparison epsilon treats 0 and .000001 as
    // equal, so a strict '<' never counted a completely stationary NPC.
    if (bb_dist2(_x,_z,_n.x,_n.z)<=.000001) _n.stuck+=_dt; else _n.stuck=0;
    bb_npc_touch_doors(_n.x,_n.z,.4);
}

function bb_ai_wander(_n,_dt,_speed,_hallway=true) {
    _n.wander_cool=max(0,_n.wander_cool-_dt);
    if (!_n.target_ready || (_n.wander_cool<=0 && (bb_dist2(_n.x,_n.z,_n.target_x,_n.target_z)<.25 || _n.stuck>1))) bb_ai_target(_n,_hallway);
    bb_ai_go(_n,_n.target_x,_n.target_z,_speed,_dt);
}

function bb_region_contains(_regions,_x,_z) {
    for (var _i=0; _i<array_length(_regions); _i++) {
        var _b=_regions[_i];
        if (_x>=_b[0] && _x<=_b[3] && _z>=_b[2] && _z<=_b[5]) return true;
    }
    return false;
}

function bb_ai_principal(_n,_dt) {
    var _g=global.G;
    if (_n.cool>0) { _n.cool=max(0,_n.cool-_dt);return; }
    if (_g.prin_chase) {
        bb_ai_go(_n,_g.px,_g.pz,_n.source.speed,_dt);
        if (!bb_region_contains(global.E.office,_n.x,_n.z) && bb_dist2(_n.x,_n.z,_g.px,_g.pz)<.7*.7 && bb_los(_n.x,_n.z,_g.px,_g.pz)) bb_give_detention(_n);
        return;
    }
    if (_n.sees && _g.guilt>0 && !bb_region_contains(global.E.office,_n.x,_n.z)) {
        _n.stare+=_dt;
        if (_n.stare>=.5) {
            _g.prin_chase=true;_n.stare=0;
            var _sound=global.S.audNoRunning;
            if (_g.guilt_type=="faculty") _sound=global.S.audNoFaculty;
            if (_g.guilt_type=="drink") _sound=global.S.audNoDrinking;
            if (_g.guilt_type=="escape") _sound=global.S.audNoEscaping;
            bb_voice_replace("principal",[_sound]);
        }
    } else _n.stare=0;
    for (var _i=0; _i<array_length(_g.npcs); _i++) {
        var _b=_g.npcs[_i];
        if (_b.kind=="bully" && _b.mode=="active" && _b.guilt>0 && !bb_region_contains(global.E.office,_n.x,_n.z) && bb_los(_n.x,_n.z,_b.x,_b.z)) {
            if (!_n.bully_seen) bb_voice_queue("principal",[global.S.clips[$ _n.source.audio.audNoBullying]]);
            _n.bully_seen=true;
            bb_ai_go(_n,_b.x,_b.z,_n.source.speed,_dt);
            if (bb_dist2(_n.x,_n.z,_b.x,_b.z)<.49) { bb_ai_bully_reset(_b);_n.bully_seen=false; }
            return;
        }
    }
    _n.bully_seen=false;
    bb_ai_wander(_n,_dt,_n.source.speed,false);
}

function bb_ai_playtime(_n,_dt) {
    var _g=global.G;
    if (_g.play_lock>0) {
        _n.cool=15;
        _n.touch=bb_dist2(_n.x,_n.z,_g.px,_g.pz)<.49;
        return;
    }
    _n.cool=max(0,_n.cool-_dt);
    if (_n.sees && _n.cool<=0 && bb_dist2(_n.x,_n.z,_g.px,_g.pz)<=256) {
        if (_n.mode!="chase") bb_ai_sound(_n,"aud_LetsPlay",true);
        _n.mode="chase";
        bb_ai_go(_n,_g.px,_g.pz,4,_dt);
    } else {
        if (_n.mode=="chase") { _n.target_ready=false;_n.mode="wander"; }
        bb_ai_wander(_n,_dt,3);
    }
    // PlayerScript uses OnTriggerEnter: contact made during playCool cannot fire
    // later unless the colliders separate and enter again.
    var _touch=bb_dist2(_n.x,_n.z,_g.px,_g.pz)<.49;
    var _entered=_touch && !_n.touch;
    _n.touch=_touch;
    if (_entered && _n.cool<=0) {
        bb_start_playtime();
        var _dx=_n.x-_g.px,_dz=_n.z-_g.pz,_len=max(.001,sqrt(_dx*_dx+_dz*_dz));
        var _p=bb_move_slide(_n.x,_n.z,_dx/_len*2,_dz/_len*2,.3,true);
        _n.x=_p[0];_n.z=_p[1];_n.cool=15;
        _n.touch=bb_dist2(_n.x,_n.z,_g.px,_g.pz)<.49;
    }
}

function bb_ai_bully_reset(_n) {
    _n.mode="hidden";_n.visible=false;_n.mode_time=random_range(60,120);_n.active_time=0;_n.spoken=false;_n.touch=false;_n.guilt=0;
}

function bb_ai_bully(_n,_dt) {
    var _g=global.G;
    if (_n.mode=="hidden") {
        _n.mode_time-=_dt;
        if (_n.mode_time>0) return;
        for (var _try=0; _try<32; _try++) {
            var _p=global.E.targets[irandom(15)];
            // Unity's Activate compares the full 3D distance against 20
            // source units. Include the authored target height so Bully does
            // not appear beside the player through a floor-level shortcut.
            if (bb_dist2(_p[0],_p[2],_g.px,_g.pz)+sqr(_p[1]-_g.py)<16 || bb_blocked_world(_p[0],_p[2],.3,false)) continue;
            _n.x=_p[0];_n.z=_p[2];_n.mode="active";_n.visible=true;_n.active_time=0;break;
        }
        return;
    }
    _n.active_time+=_dt;_n.guilt=max(0,_n.guilt-_dt);
    var _dd=bb_dist2(_g.px,_g.pz,_n.x,_n.z)+sqr(_g.py-_n.y);
    if (_n.active_time>=180 && _dd>=576) { bb_ai_bully_reset(_n);return; }
    if (_n.sees && _dd<=36) {
        if (!_n.spoken) { bb_ai_sound(_n,"aud_Taunts");_n.spoken=true; }
        _n.guilt=10;
    }
    var _touch=(_dd<1.3*1.3 && bb_los(_n.x,_n.z,_g.px,_g.pz));
    if (_touch && !_n.touch) {
        if (bb_inv_take_random()) { bb_ai_sound(_n,"aud_Thanks",true);bb_ai_bully_reset(_n);return; }
        bb_ai_sound(_n,"aud_Denied",true);
    }
    _n.touch=_touch;
}

function bb_ai_bully_blocks(_x,_z) {
    for (var _i=0; _i<array_length(global.G.npcs); _i++) {
        var _n=global.G.npcs[_i];
        if (_n.kind=="bully" && _n.live && _n.mode=="active" && bb_dist2(_x,_z,_n.x,_n.z)<sqr(.8+global.G.radius)) return true;
    }
    return false;
}

function bb_ai_sweep(_n,_dt) {
    var _g=global.G;
    _n.mode_time-=_dt;
    if (_n.mode=="rest") {
        if (_n.mode_time>0) return;
        _n.mode="sweep";_n.wanders=1;bb_ai_target(_n);bb_ai_sound(_n,"aud_Intro",true);
    }
    if (_n.mode=="home") {
        bb_ai_go(_n,_n.home_x,_n.home_z,_n.source.speed,_dt);
        if (bb_dist2(_n.x,_n.z,_n.home_x,_n.home_z)<.25) _n.mode="rest";
    } else {
        _n.wander_cool=max(0,_n.wander_cool-_dt);
        if (_n.wander_cool<=0 && (bb_dist2(_n.x,_n.z,_n.target_x,_n.target_z)<.25 || _n.stuck>1)) {
            if (_n.wanders>=5) { _n.mode="home";_n.mode_time=random_range(120,180); }
            else { _n.wanders++;bb_ai_target(_n); }
        }
        bb_ai_go(_n,_n.target_x,_n.target_z,_n.source.speed,_dt);
    }
    if (_g.boots<=0 && bb_dist2(_g.px,_g.pz,_n.x,_n.z)<1 && bb_los(_n.x,_n.z,_g.px,_g.pz)) {
        var _p=bb_move_slide(_g.px,_g.pz,_n.vx*_dt,_n.vz*_dt,_g.radius,true);_g.px=_p[0];_g.pz=_p[1];
        bb_ai_sound(_n,"aud_Sweep");
    }
    if (_g.baldi_active && bb_dist2(_g.baldi_x,_g.baldi_z,_n.x,_n.z)<1) {
        var _p=bb_move_slide(_g.baldi_x,_g.baldi_z,_n.vx*_dt,_n.vz*_dt,.28,true);_g.baldi_x=_p[0];_g.baldi_z=_p[1];
    }
}

function bb_ai_crafters(_n,_dt) {
    var _g=global.G;
    for (var _i=0; _i<array_length(global.E.craft_triggers); _i++) {
        var _trigger=global.E.craft_triggers[_i],_b=_trigger.bounds;
        var _inside=bb_aabb_hit(_g.px,_g.pz,_g.radius,_b[0],_b[2],_b[3],_b[5]);
        if (_inside!=_g.craft_inside[_i] && !_n.angry) {
            var _p=_inside?_trigger.go:_trigger.flee;
            _n.target_x=_p[0];_n.target_z=_p[2];_n.target_ready=true;
            if (!_inside) _n.force_show=3;
        }
        _g.craft_inside[_i]=_inside;
    }
    _n.force_show=max(0,_n.force_show-_dt);
    if (_n.angry) {
        bb_ai_sound(_n,"aud_Loop");
        _n.spd+=12*_dt;bb_ai_go(_n,_g.px,_g.pz,_n.spd,_dt);
        if (bb_dist2(_n.x,_n.z,_g.px,_g.pz)<.49) {
            _g.px=0;_g.pz=-15;_g.yaw=0;_g.baldi_x=0;_g.baldi_z=-24;bb_hear_pri(0,-15,8);
            _n.live=false;_n.visible=false;
            if (_n.sound!=-1) audio_stop_sound(_n.sound);
        }
        return;
    }
    if (_n.target_ready) bb_ai_go(_n,_n.target_x,_n.target_z,_n.source.speed,_dt);
    var _dd=bb_dist2(_n.x,_n.z,_g.px,_g.pz);
    _n.visible=(_n.force_show>0 || (bb_dist2(_n.x,_n.z,_n.target_x,_n.target_z)<=16 && _dd>=144));
    var _dot=(-sin(_g.yaw)*(_n.x-_g.px)-cos(_g.yaw)*(_n.z-_g.pz))/max(.001,sqrt(_dd));
    if (_g.notebooks>=7 && _n.visible && _n.sees && _dot>.79) _n.stare+=_dt; else _n.stare=max(0,_n.stare-_dt);
    if (_n.stare>=1) {
        _n.angry=true;_n.spd=_n.source.speed;
        if (variable_struct_exists(_n.source,"angry_texture")) _n.spr=global.PS[$ _n.source.angry_texture];
        bb_ai_sound(_n,"aud_Intro",true);
    }
}

function bb_ai_prize(_n,_dt) {
    var _g=global.G;
    if (_n.crazy>0) { _n.crazy=max(0,_n.crazy-_dt);_n.dir+=180*_dt;_n.spd=0;return; }
    if (_n.sees) {
        if (!_n.player_seen) bb_ai_sound(_n,"aud_Found");
        _n.player_seen=true;_n.cool=.5;
        _n.target_x=_g.px;_n.target_z=_g.pz;_n.target_ready=true;
    } else {
        _n.cool=max(0,_n.cool-_dt);
        if (_n.player_seen && _n.cool<=0) {
            bb_ai_sound(_n,"aud_Lost");_n.player_seen=false;_n.target_ready=false;
        }
        if (!_n.target_ready || bb_dist2(_n.x,_n.z,_n.target_x,_n.target_z)<.25 || _n.stuck>1) bb_ai_target(_n);
    }
    var _wp=bb_nav_step(_n.x,_n.z,_n.target_x,_n.target_z);
    var _want=point_direction(_n.x,_n.z,_wp[0],_wp[1]);
    var _diff=((_want-_n.dir+540) mod 360)-180;
    _n.dir+=clamp(_diff,-_n.source.turnSpeed*_dt,_n.source.turnSpeed*_dt);
    _n.vx=0;_n.vz=0;
    if (abs(_diff)>=5) { _n.spd=0;return; }
    _n.spd=min(_n.sees?_n.source.runSpeed:_n.source.normSpeed,_n.spd+_n.source.accel*_dt);
    bb_ai_go(_n,_n.target_x,_n.target_z,_n.spd,_dt);
    if (!_n.hug_announced && bb_dist2(_g.px,_g.pz,_n.x,_n.z)<1 && bb_los(_n.x,_n.z,_g.px,_g.pz)) {
        if (_n.sound==-1 || !audio_is_playing(_n.sound)) { bb_ai_sound(_n,"aud_Hug");_n.hug_announced=true; }
    }
    if (_g.boots<=0 && _n.spd>1 && bb_dist2(_g.px,_g.pz,_n.x,_n.z)<1 && bb_los(_n.x,_n.z,_g.px,_g.pz)) {
        var _p=bb_move_slide(_g.px,_g.pz,_n.vx*_dt,_n.vz*_dt,_g.radius,true);_g.px=_p[0];_g.pz=_p[1];
    }
}
