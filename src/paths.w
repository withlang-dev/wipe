use c_import("raylib.h")

c facade paths:
    domain directory process
    fn GetApplicationDirectory
        returns borrow CStr from domain directory

pub fn asset_path(name: &str) -> str:
    // raylib owns a mutable static buffer. Own its text before another call.
    let directory = GetApplicationDirectory().unwrap().to_str().unwrap().clone()
    f"{directory}/assets/{name}"
