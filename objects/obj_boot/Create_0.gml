randomize();
visible = true;
window_set_caption("Baldi's Basics In Education And Learning");
bb_res_init();
gpu_set_texfilter(false);

var font_path = "fonts/COMIC.ttf";
if (!file_exists(font_path)) {
    font_path = working_directory + "fonts/COMIC.ttf";
}
global.fnt_ui = font_add(font_path, 16, false, false, 32, 127);
global.fnt_small = font_add(font_path, 12, false, false, 32, 127);
global.fnt_big = font_add(font_path, 20, false, false, 32, 127);

global.spr_wave = [];
var i;
for (i = 0; i < 100; i++) {
    var fname = "tex/baldi_wave/" + bb_pad2(i) + ".png";
    if (!file_exists(fname)) {
        fname = working_directory + "tex/baldi_wave/" + bb_pad2(i) + ".png";
    }
    var spr = sprite_add(fname, 1, false, false, 71, 128);
    if (spr == -1) {
        spr = spr_baldi_idle;
    }
    array_push(global.spr_wave, spr);
}

global.spr_slap = [];
var slap_names = ["0000", "0006", "0012", "0018", "0024"];
for (i = 0; i < 5; i++) {
    var sfname = "tex/baldi_slap/" + slap_names[i] + ".png";
    if (!file_exists(sfname)) {
        sfname = working_directory + "tex/baldi_slap/" + slap_names[i] + ".png";
    }
    var sf = sprite_add(sfname, 1, false, false, 53, 128);
    if (sf == -1) {
        sf = spr_baldi_idle;
    }
    array_push(global.spr_slap, sf);
}

bb3d_init();
bb_presentation_init();

var _keep = 0;
_keep += sprite_get_width(spr_playtime) + sprite_get_width(spr_bully) + sprite_get_width(spr_sweep);
_keep += sprite_get_width(spr_crafters) + sprite_get_width(spr_prize) + sprite_get_width(spr_cursor);
_keep += sprite_get_width(spr_nb_red) + sprite_get_width(spr_nb_blue) + sprite_get_width(spr_nb_yellow);
_keep += sprite_get_width(spr_nb_cyan) + sprite_get_width(spr_nb_salmon) + sprite_get_width(spr_nb_black);
_keep += sprite_get_width(spr_tex_sky_up) + sprite_get_width(spr_tex_sky_down) + sprite_get_width(spr_tex_grass);
_keep += sprite_get_width(spr_key) + sprite_get_width(spr_quarter);
_keep += audio_sound_length(snd_door_open) + audio_sound_length(snd_bal_doors);
global.spr_nb_green = bb_load_png("tex/extra/nb_green.png", 0, 0);
global.spr_faculty = bb_load_png("tex/extra/faculty0.png", 0, 0);
global.spr_faculty_open = bb_load_png("tex/extra/faculty80.png", 0, 0);
global.spr_swing_locked = bb_load_png("tex/extra/swing_locked.png", 0, 0);
if (global.spr_nb_green != -1) {
    _keep += sprite_get_width(global.spr_nb_green);
}
global.spr_npc_play = bb_load_png_rb("tex/npc/playtime.png");
global.spr_npc_bully = bb_load_png_rb("tex/npc/bully.png");
global.spr_npc_sweep = bb_load_png_rb("tex/npc/sweep.png");
global.spr_npc_craft = bb_load_png_rb("tex/npc/crafters.png");
global.spr_npc_prize = bb_load_png_rb("tex/npc/prize.png");
global.spr_npc_prin = bb_load_png_rb("tex/npc/principal.png");
_keep += audio_sound_length(snd_bal_prize);
global.keep_assets = _keep;

global.bb_selftest = false;
for (var _arg = 1; _arg <= parameter_count(); _arg++) {
    if (parameter_string(_arg) == "--bb-self-test") global.bb_selftest = true;
}
room_goto(global.bb_selftest ? rm_school : rm_title);
