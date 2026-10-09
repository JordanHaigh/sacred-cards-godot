mod ui;

use macroquad::prelude::*;
use sacred_cards::data::Database;
use std::path::PathBuf;

fn window_conf() -> Conf {
    Conf {
        window_title: "Yu-Gi-Oh! The Sacred Cards · Rust".into(),
        window_width: 1280,
        window_height: 800,
        high_dpi: true,
        sample_count: 1,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    let root = std::env::var_os("SACRED_ASSETS")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            let bundled = std::env::current_exe().ok().and_then(|p| {
                p.parent()
                    .and_then(|p| p.parent())
                    .map(|p| p.join("Resources/assets"))
            });
            bundled.filter(|p| p.is_dir()).unwrap_or_else(|| {
                PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("sacred-cards-decompiled/build/assets")
            })
        });
    let db = match Database::load(&root) {
        Ok(db) => db,
        Err(error) => {
            eprintln!("Cannot load game assets: {error}");
            loop {
                clear_background(Color::from_hex(0x101521));
                draw_text(
                    "The Sacred Cards — asset loading failed",
                    40.,
                    70.,
                    32.,
                    WHITE,
                );
                draw_text(&error, 40., 120., 20., Color::from_hex(0xe9ba6c));
                draw_text(
                    "Set SACRED_ASSETS to the recovered build/assets directory.",
                    40.,
                    160.,
                    20.,
                    WHITE,
                );
                if is_key_pressed(KeyCode::Escape) {
                    return;
                }
                next_frame().await;
            }
        }
    };
    let args: Vec<String> = std::env::args().collect();
    let smoke = args.iter().position(|a| a == "--smoke").map(|i| {
        (
            args.get(i + 1).cloned().unwrap_or_else(|| "title".into()),
            args.get(i + 2)
                .cloned()
                .unwrap_or_else(|| "/private/tmp/sacred-cards.png".into()),
        )
    });
    let mut app = ui::App::new(db);
    if let Some((screen, _)) = &smoke {
        app.prepare_smoke(screen);
    }
    let mut frames = 0;
    loop {
        app.frame();
        if smoke.is_none() {
            app.sync_music().await;
        }
        frames += 1;
        if let Some((_, path)) = &smoke {
            if frames == 12 {
                get_screen_data().export_png(path);
                println!("Rendered {} to {path}", smoke.as_ref().unwrap().0);
                return;
            }
        }
        next_frame().await;
        if app.quit {
            break;
        }
    }
}
