// The sole raw uniform boundary. Each wrapper supplies the exact f32 layout
// required by its GL uniform kind. raylib/glUniform copies these stack bytes
// synchronously; no pointer survives the call. No raw pointers reach gameplay.
use c_import("raylib.h")
use paths

c facade gpu:
    resource Program wraps Shader
        from LoadShader
        drop UnloadShader
    fn LoadShader
        of Program
        rename load
        param vsFileName fixed null

pub type Effect { program: Program }
pub fn Effect.open(name: &str) -> Effect:
    Effect { program: Program.load(asset_path(f"shaders/{name}")) }
extend Effect:
    pub fn location(self: &Self, name: &str) -> i32:
        GetShaderLocation(self.program.repr, name)
    pub fn begin(self: &Self) -> Unit: BeginShaderMode(self.program.repr)
    pub fn scalar(self: &Self, location: i32, value: f32) -> Unit:
        unsafe { SetShaderValue(self.program.repr, location, &raw const value, SHADER_UNIFORM_FLOAT) }
    pub fn vector2(self: &Self, location: i32, x: f32, y: f32) -> Unit:
        let data: [f32; 2] = [x, y]
        unsafe { SetShaderValue(self.program.repr, location, &raw const data[0], SHADER_UNIFORM_VEC2) }
    pub fn vector4(self: &Self, location: i32, x: f32, y: f32, z: f32, w: f32) -> Unit:
        let data: [f32; 4] = [x, y, z, w]
        unsafe { SetShaderValue(self.program.repr, location, &raw const data[0], SHADER_UNIFORM_VEC4) }
    pub fn texture(self: &Self, location: i32, texture: Texture2D) -> Unit:
        SetShaderValueTexture(self.program.repr, location, texture)
