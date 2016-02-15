use super::BlockData;
use super::{ SECTION_BUF_LEN };

// TODO: This might be faster if we eliminate the branch?
fn nibble_array_get(arr: &[u8; SECTION_BUF_LEN/2], idx: usize) -> u8 {
    let val = arr[idx >> 1];
    // TODO: Is this right?
    match idx % 2 {
        0 => val & 0x0f,
        _ => val >> 4,
    }
}
// TODO: This might be faster if we eliminate the branch?
fn nibble_array_put(arr: &mut [u8; SECTION_BUF_LEN/2], idx: usize, val: u8) {
    let arr_idx = idx >> 1;
    let orig = arr[arr_idx];
    arr[arr_idx] = match idx % 2 {
        0 => (orig & 0xf0) | (val & 0x0f),
        _ => (orig & 0x0f) | (val << 4),
    };
}

#[derive(PartialEq, Clone)]
pub enum SkylightRayCastState {
    Finished,
    CastShade,
    CastLight,
}

pub struct ChunkSection {
    block_data: [BlockData; SECTION_BUF_LEN], // 2 bytes per block
    block_light: [u8; SECTION_BUF_LEN / 2], // 1/2 byte per block
    skylight: [u8; SECTION_BUF_LEN / 2], // 1/2 byte per block
    count: u16,
}

impl ChunkSection {
    #[inline(always)]
    pub fn block_array_index(x: u16, y: u16, z: u16) -> usize {
        ((x & 15) | ((z & 15) << 4) | ((y & 15) << 8)) as usize
    }

    pub fn get_block(&self, x: u16, y: u16, z: u16) -> &BlockData {
        &self.block_data[ChunkSection::block_array_index(x, y, z)]
    }
    pub fn set_block_raw(&mut self, x: u16, y: u16, z: u16, block: BlockData) {
        self.block_data[ChunkSection::block_array_index(x, y, z)] = block;
    }
    pub fn set_block(&mut self, x: u16, y: u16, z: u16, block: BlockData) {
        if self.get_block(x, y, z).is_air() && !block.is_air() {
            self.count += 1;
        } else if !self.get_block(x, y, z).is_air() && block.is_air() {
            self.count -= 1;
        }
        self.set_block_raw(x, y, z, block);
    }

    pub fn get_skylight_value(&self, x: u16, y: u16, z: u16) -> u8 {
        nibble_array_get(&self.skylight, 
                         ChunkSection::block_array_index(x, y, z))
    }
    pub fn set_skylight_value(&mut self, x: u16, y: u16, z: u16, val: u8) {
        nibble_array_put(&mut self.skylight, 
                         ChunkSection::block_array_index(x, y, z), val);
    }
    pub fn get_blocklight_value(&self, x: u16, y: u16, z: u16) -> u8 {
        nibble_array_get(&self.block_light, 
                         ChunkSection::block_array_index(x, y, z))
    }
    pub fn set_blocklight_value(&mut self, x: u16, y: u16, z: u16, val: u8) {
        nibble_array_put(&mut self.block_light, 
                         ChunkSection::block_array_index(x, y, z), val);
    }

    pub fn cast_skylight_ray(&mut self, x: u16, z: u16, 
                         over: SkylightRayCastState) -> SkylightRayCastState {
        fn is_opaque(block: u16) -> bool { block != 0 }

        if over == SkylightRayCastState::Finished { return over; }

        let mut hit_opaque = 
            if over == SkylightRayCastState::CastShade { true } else { false };

        for y in (0..16).rev() {
            let curr_skylight = self.get_skylight_value(x, y, z);
            let curr_id = self.get_block(x, y, z).get_id();
            if hit_opaque {
                if curr_skylight != 15 { return SkylightRayCastState::Finished; }
                self.set_skylight_value(x, y, z, 0);
            } else {
                if is_opaque(curr_id) { 
                    if curr_skylight != 15 { return SkylightRayCastState::Finished; }
                    self.set_skylight_value(x, y, z, 0);
                    hit_opaque = true; 
                } else {
                    self.set_skylight_value(x, y, z, 15);
                }
            }
        }

        if hit_opaque {
            SkylightRayCastState::CastShade
        } else {
            SkylightRayCastState::CastLight
        }
    }

    pub fn recount(&mut self) {
        self.count = 0;
        for block in &self.block_data[..] {
            if !block.is_air() {
                self.count += 1;
            }
        }
    }
    pub fn is_empty(&self) -> bool {
        //for block in &self.block_data[..] {
        //    if !block.is_air() {
        //        return false;
        //    }
        //}
        //true
        self.count == 0
    }

    pub fn borrow_block_data(&self) -> &[BlockData; SECTION_BUF_LEN] {
        return &self.block_data;
    }
    pub fn borrow_light_data(&self) -> &[u8; SECTION_BUF_LEN / 2] {
        return &self.block_light;
    }
    pub fn borrow_skylight_data(&self) -> &[u8; SECTION_BUF_LEN / 2] {
        return &self.skylight;
    }
}
impl Default for ChunkSection {
    fn default() -> ChunkSection {
        ChunkSection {
            block_data: [BlockData::default(); SECTION_BUF_LEN],
            block_light: [0u8; SECTION_BUF_LEN / 2],
            skylight: [0u8; SECTION_BUF_LEN / 2],
            count: 0,
        }
    }
}
