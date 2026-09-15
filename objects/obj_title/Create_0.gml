menu_open = false;
audio_stop_all();
audio_play_sound(snd_mus_intro, 1, false);
audio_play_sound(snd_bal_menu, 2, false);
window_set_cursor(cr_default);
window_mouse_set_locked(false);

btn_start = {x1: 300, y1: 420, x2: 420, y2: 468};
btn_menu = {x1: 500, y1: 420, x2: 610, y2: 468};
btn_back = {x1: 20, y1: 420, x2: 140, y2: 468};
