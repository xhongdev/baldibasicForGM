function bb_audio_init() {
    global.G.voices = {
        math: {queue:[], head:0, handle:-1},
        tutor: {queue:[], head:0, handle:-1},
        principal: {queue:[], head:0, handle:-1}
    };
    global.G.audio_log = [];
    global.G.finale_sound = -1;
    global.G.finale_loop = false;
    global.G.lock_voice_cd = 0;
}

function bb_sound_play(_clip, _loop = false, _priority = 2, _gain = 1) {
    if (_gain <= 0) return -1;
    var _handle = audio_play_sound(_clip, _priority, _loop);
    audio_sound_gain(_handle, _gain, 0);
    if (global.bb_selftest) array_push(global.G.audio_log, {clip:_clip, handle:_handle});
    return _handle;
}

function bb_world_gain(_x, _z, _range) {
    var _distance = sqrt(bb_dist2(global.G.px, global.G.pz, _x, _z));
    if (_distance >= _range) return 0;
    return min(1, 2 / max(2, _distance)) * clamp((_range-_distance) / 4, 0, 1);
}

function bb_world_sound(_clip, _x, _z, _priority = 2, _range = 24) {
    return bb_sound_play(_clip, false, _priority, bb_world_gain(_x, _z, _range));
}

function bb_voice_clear(_channel) {
    var _v = global.G.voices[$ _channel];
    if (_v.handle != -1) audio_stop_sound(_v.handle);
    _v.handle = -1;
    _v.queue = [];
    _v.head = 0;
}

function bb_voice_queue(_channel, _clips) {
    var _v = global.G.voices[$ _channel];
    for (var _i = 0; _i < array_length(_clips); _i++) array_push(_v.queue, _clips[_i]);
}

function bb_voice_replace(_channel, _clips) {
    bb_voice_clear(_channel);
    bb_voice_queue(_channel, _clips);
}

function bb_audio_update(_dt) {
    var _g = global.G;
    var _channels = (_g.state == "yctp") ? ["math"] : ["tutor", "principal"];
    for (var _i = 0; _i < array_length(_channels); _i++) {
        var _channel = _channels[_i];
        var _v = _g.voices[$ _channel];
        var _gain = 1;
        if (_channel == "principal") {
            for (var _ni = 0; _ni < array_length(_g.npcs); _ni++) {
                var _npc = _g.npcs[_ni];
                if (_npc.kind == "principal") _gain = bb_world_gain(_npc.x, _npc.z, 40);
            }
        }
        if (_v.handle != -1 && audio_is_playing(_v.handle)) {
            audio_sound_gain(_v.handle, _gain, 0);
        } else if (_v.head < array_length(_v.queue)) {
            _v.handle = bb_sound_play(_v.queue[_v.head], false, 3, max(0.001, _gain));
            _v.head += 1;
        }
    }
    if (_g.state == "play") {
        _g.lock_voice_cd = max(0, _g.lock_voice_cd - _dt);
        if (_g.exit_got == 3 && !_g.finale_loop && _g.finale_sound != -1 && !audio_is_playing(_g.finale_sound)) {
            _g.finale_sound = bb_sound_play(global.S.aud_MachineLoop, true, 1, 0.8);
            _g.finale_loop = true;
        }
    }
}

function bb_math_voice_problem() {
    var _g = global.G;
    if (_g.spoop_mode || _g.yctp_end) return;
    bb_voice_queue("math", [global.S[$ "bal_problems" + string(_g.yctp_q-1)]]);
    if (_g.yctp_corrupt) {
        bb_voice_queue("math", [global.S.bal_screech, global.S.bal_plus, global.S.bal_screech, global.S.bal_equals]);
    } else {
        bb_voice_queue("math", [global.S[$ "bal_numbers" + string(_g.yctp_a)],
            _g.yctp_op == "+" ? global.S.bal_plus : global.S.bal_minus,
            global.S[$ "bal_numbers" + string(_g.yctp_b)], global.S.bal_equals]);
    }
}

function bb_finale_audio(_stage) {
    var _g = global.G;
    if (_g.finale_sound != -1) audio_stop_sound(_g.finale_sound);
    if (_stage == 1) {
        bb_sound_play(global.S.aud_Switch, false, 3, 0.8);
        _g.finale_sound = bb_sound_play(global.S.aud_MachineQuiet, true, 1, 0.8);
    } else if (_stage == 2) {
        _g.finale_sound = bb_sound_play(global.S.aud_MachineStart, true, 1, 0.8);
    } else {
        _g.finale_sound = bb_sound_play(global.S.aud_MachineRev, false, 1, 0.8);
        _g.finale_loop = false;
    }
}
