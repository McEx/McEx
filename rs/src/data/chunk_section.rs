use super::BlockData;
use super::{ SECTION_BUF_LEN };

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

    //pub fn calc_skylight(&mut self, blocks_above: [u16; 16]) {
    //    for (z_idx, slice) in blocks_above.iter().enumerate() {
    //        let mut slice_a = slice;
    //        for x_idx in 0..16 {
    //            slice_a = slice_a >> 1;
    //            let col_light = (slice_a && 1) == 1;
    //            if col_light {
    //                
    //            }
    //        }
    //    }
    //}

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
