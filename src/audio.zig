const raylib = @cImport(@cInclude("raylib.h"));

pub const AudioDevice = struct {
    beep: raylib.Sound,

    pub fn init() AudioDevice {
        raylib.InitAudioDevice();
        const beep = raylib.LoadSound("sound/beep.wav");
        return AudioDevice{ .beep = beep };
    }

    pub fn deinit(self: *const AudioDevice) void {
        raylib.UnloadSound(self.beep);
        raylib.CloseAudioDevice();
    }

    pub fn play(self: *AudioDevice) void {
        if (raylib.IsSoundPlaying(self.beep))
            return;

        raylib.PlaySound(self.beep);
        raylib.SetSoundVolume(self.beep, 0.25);
    }

    pub fn stop(self: *AudioDevice) void {
        if (!raylib.IsSoundPlaying(self.beep))
            return;

        raylib.StopSound(self.beep);
    }
};
