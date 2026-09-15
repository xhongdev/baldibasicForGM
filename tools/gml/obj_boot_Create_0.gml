randomize();
visible = true;
window_set_caption("Baldi's Basics In Education And Learning");
bb_res_init();
gpu_set_texfilter(false);

var font_path = "fonts/COMIC.ttf";
if (!file_exists(font_path)) {
    font_path = working_directory + "fonts/COMIC.ttf";
}
global.fnt_ui = font_add(font_path, 24, false, false, 32, 127);
global.fnt_small = font_add(font_path, 16, false, false, 32, 127);
global.fnt_big = font_add(font_path, 32, false, false, 32, 127);

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
    var sf = sprite_add(sfname, 1, false, false, 71, 128);
    if (sf == -1) {
        sf = spr_baldi_idle;
    }
    array_push(global.spr_slap, sf);
}

bb3d_init();

var _keep = 0;
_keep += sprite_get_width(spr_playtime) + sprite_get_width(spr_bully) + sprite_get_width(spr_sweep);
_keep += sprite_get_width(spr_crafters) + sprite_get_width(spr_prize) + sprite_get_width(spr_cursor);
_keep += sprite_get_width(spr_nb_red) + sprite_get_width(spr_nb_blue) + sprite_get_width(spr_nb_yellow);
_keep += sprite_get_width(spr_nb_cyan) + sprite_get_width(spr_nb_salmon) + sprite_get_width(spr_nb_black);
_keep += sprite_get_width(spr_tex_sky_up) + sprite_get_width(spr_tex_sky_down) + sprite_get_width(spr_tex_grass);
_keep += sprite_get_width(spr_key) + sprite_get_width(spr_quarter);
_keep += audio_sound_length(snd_door_open) + audio_sound_length(snd_bal_doors);
global.keep_assets = _keep;

room_goto(rm_title);
