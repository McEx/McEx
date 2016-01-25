extern crate image;
extern crate opensimplex;
extern crate noise;

use std::fs::File;
use std::path::Path;
use std::cmp;

use image::{ GenericImage, ImageBuffer };
use opensimplex::OsnContext;

fn diff(sample1: f64, sample2: f64, base: f64) -> bool {
    (sample1 < base && sample2 > base) || (sample1 > base && sample2 < base)
}

fn transform_samples(sample1: f64, sample2: f64) -> f64 { sample1 * (1.0 / (sample1 - sample2).abs()) }
fn max(v1: f64, v2: f64) -> f64 { if v1 > v2 { v1 } else { v2 } }
fn get_ocean_value(noise: &OsnContext, x: f64, y: f64) -> f64 {
    let base = 0f64;
    let sample1 = noise.noise2(x / 1200.0, y / 1200.0) + base;
    let mut sample2 = 0f64;
    let mut sa = 0f64;
    let mut highest = 0f64;

    if sample1 == 0.0 {
        highest = 1.0;
    }

    sample2 = noise.noise2((x - 100.0) / 1200.0, y / 1200.0) + base;
    if diff(sample1, sample2, base) {
        sa = transform_samples(sample1, sample2);
        highest = max(1.0 - sa.abs(), highest);
    } else {
        sample2 = noise.noise2((x + 100.0) / 1200.0, y / 1200.0) + base;
        if diff(sample1, sample2, base) {
            sa = transform_samples(sample1, sample2);
            highest = max(1.0 - sa.abs(), highest);
        }
    }

    sample2 = noise.noise2(x / 1200.0, (y + 100.0) / 1200.0) + base;
    if diff(sample1, sample2, base) {
        sa = transform_samples(sample1, sample2);
        highest = max(1.0 - sa.abs(), highest);
    } else {
        sample2 = noise.noise2(x / 1200.0, (y - 100.0) / 1200.0) + base;
        if diff(sample1, sample2, base) {
            sa = transform_samples(sample1, sample2);
            highest = max(1.0 - sa.abs(), highest);
        }
    }

    if sample1 > 0.0 {
        highest = 2.0 - highest;
    }

    highest
}

fn main() {
    let seed = 12;
    let noise1 = OsnContext::new(seed).unwrap();
    let noise2 = OsnContext::new(seed + 1).unwrap();

    let img = ImageBuffer::from_fn(1024, 1024, |x, z| {
        //let c1 = ((noise1.noise2(x as f64 / 64f64, z as f64 / 64f64) + 1f64) * 128f64) as u8;
        //let c2 = ((noise2.noise2(x as f64 / 64f64, z as f64 / 64f64) + 1f64) * 128f64) as u8;
        //image::Rgb([c1, c2, 0u8])
        image::Luma([((get_ocean_value(&noise1, x as f64 * 16.0, z as f64 * 16.0) + 1f64) * 128f64) as u8])
    });

    let _ = img.save("biomes.png").unwrap();
}
/*
struct Rect {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
}
impl Rect {
    pub fn new(x0: f64, y0: f64, x1: f64, y1: f64) -> Self {
        Rect {
            x0: x0,
            y0: y0,
            x1: x1,
            y1: y1,
        }
    }
    pub fn contains(&self, x: f64, y: f64) -> bool {
        (x <= self.x1) && (x > self.x0) && (y <= self.y1) && (y > self.y0)
    }
}

fn biome_whittaker() -> Vec<(Rect, u8)> {
    vec![
        (Rect::new(0.0, 0.0, 0.5, 0.2), 1), // Tundra
        (Rect::new(0.5, 0.0, 0.95, 0.2), 2), // Savanna
        (Rect::new(0.95, 0.0, 1.0, 0.5), 3), // Desert
        (Rect::new(0.2, 0.2, 0.5, 0.5), 4), // Taiga
        (Rect::new(0.5, 0.2, 0.97, 0.35), 5), // Shrubland
        (Rect::new(0.97, 0.2, 1.0, 0.45), 6), // Plains
        (Rect::new(0.5, 0.5, 0.7, 0.7), 7), // Swampland
        (Rect::new(0.5, 0.35, 0.97, 1.0), 8), // Forest
        // TODO: Seasonal forest, rainforest
    ]
}
fn find_biome(whittaker: &Vec<(Rect, u8)>, x: f64, y: f64) -> u8 {
    for &(ref rect, id) in whittaker {
        if rect.contains(x, y) {
            return id;
        }
    }
    return 0;
}

use image::Rgb;

fn main() {
    let seed = 12;
    let noise1 = OsnContext::new(seed).unwrap();
    let noise2 = OsnContext::new(seed + 1).unwrap();

    let seed = noise::Seed::new(12);

    let whittaker = biome_whittaker();
    let biome_colors = [Rgb([0, 0, 0]), Rgb([255, 0, 0]), Rgb([255, 255, 0]), Rgb([255, 255, 255]), Rgb([255, 0, 255]), Rgb([0, 255, 0]), Rgb([0, 255, 255]), Rgb([0, 0, 255]), Rgb([100, 0, 0])];

    let img = ImageBuffer::from_fn(1024, 1024, |x, z| {
        let (cell, dist) = noise::cell2_seed_point(&seed, &[x as f32 / 16f32, z as f32 / 16f32], noise::range_sqr_euclidian2);
        let c1 = (noise1.noise2(cell[0] as f64 / 8f64, cell[1] as f64 / 8f64) + 1.0) / 2.0;
        let c2 = (noise2.noise2(cell[0] as f64 / 8f64, cell[1] as f64 / 8f64) + 1.0) / 2.0;

        let biome_id = if c1 + c2 <= 1.0 {
            find_biome(&whittaker, c1, c2)
        } else {
            find_biome(&whittaker, 1.0-c1, 1.0-c2)
        };
        //let c1 = ((noise1.noise2(x as f64 / 64f64, z as f64 / 64f64) + 1f64) * 128f64) as u8;
        //let c2 = ((noise2.noise2(x as f64 / 64f64, z as f64 / 64f64) + 1f64) * 128f64) as u8;
        //image::Rgb([c1, c2, 0u8])
        biome_colors[biome_id as usize]
    });

    let _ = img.save("biomes.png").unwrap();
}

#[cfg(test)]
mod test {
    #[test]
    fn it_works() {
    }
}*/
