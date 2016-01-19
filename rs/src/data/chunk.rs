use super::{ ChunkSection, BlockData };
use super::{ CHUNK_SECTION_HEIGHT, BIOME_BUF_LEN, MAX_BITMASK, SECTION_BUF_LEN };
#[allow(unused_imports)]
use super::byteorder::{LittleEndian, WriteBytesExt};

#[NifResource]
pub struct Chunk {
    sections: [ChunkSection; CHUNK_SECTION_HEIGHT],
    biome: [u8; BIOME_BUF_LEN], // 1 byte per block column
}

fn count_bits(num: u16) -> u8 {
    let mut res = 0;
    let mut num = num;
    while num > 0 {
        res += 1;
        num = num & (num - 1);
    }
    res
}

impl Chunk {
    #[inline(always)]
    fn section_array_index(y: u16) -> usize {
        ((y >> 4) & 15) as usize
    }
    pub fn get_block(&self, x: u16, y: u16, z: u16) -> &BlockData {
        self.sections[Chunk::section_array_index(y)].get_block(x, y, z)
    }
    pub fn set_block(&mut self, x: u16, y: u16, z: u16, block: BlockData) {
        self.sections[Chunk::section_array_index(y)].set_block(x, y, z, block);
    }

    fn count_bytes(entire_chunk: bool, num_sections: u8, skylight: bool) -> u32 {
        let mut byte_size: u32 = 0;

        let mut section_size: u32 = (SECTION_BUF_LEN as u32) * 5 / 2;
        if skylight { section_size += (SECTION_BUF_LEN as u32) / 2 };
        byte_size += num_sections as u32 * section_size;

        if entire_chunk { byte_size += BIOME_BUF_LEN as u32 };

        byte_size
    }

    pub fn get_transmit_size(&self, skylight: bool, entire_chunk: bool, bitmask: u16) -> usize {
        let mut section_bitmask: u16;
        if entire_chunk {
            section_bitmask = MAX_BITMASK;
        } else {
            section_bitmask = bitmask & MAX_BITMASK;
        }

        for section_num in 0..CHUNK_SECTION_HEIGHT {
            let section = &self.sections[section_num];
            if section.is_empty() {
                section_bitmask = section_bitmask & !(1 << section_num);
            }

        }
        let num_sections = count_bits(section_bitmask);
        Chunk::count_bytes(entire_chunk, num_sections, skylight) as usize
    }

    pub fn write_transmit_data(&self, skylight: bool, entire_chunk: bool, bitmask: u16, 
                               mut buffer: &mut [u8]) -> (u16, u32) {
        let mut section_bitmask: u16;
        if entire_chunk {
            section_bitmask = MAX_BITMASK;
        } else {
            section_bitmask = bitmask & MAX_BITMASK;
        }
        //let time_1 = ::time::now();

        let mut added_sections: Vec<&ChunkSection> = Vec::with_capacity(16);
        for section_num in 0..CHUNK_SECTION_HEIGHT {
            let section = &self.sections[section_num];
            if section.is_empty() {
                section_bitmask = section_bitmask & !(1 << section_num);
            }

            if section_bitmask & (1 << section_num) != 0 {
                added_sections.push(section);
            }
        }
        let num_sections = count_bits(section_bitmask);
        let byte_size = Chunk::count_bytes(entire_chunk, num_sections, skylight);
        //let time_2 = ::time::now();

        // Block types
        for section in &added_sections { 
            for block in &section.borrow_block_data()[..] {
                buffer.write_u16::<LittleEndian>(*block.get_value()).unwrap();
            }
        }
        // Block light
        for section in &added_sections {
            for light in &section.borrow_light_data()[..] {
                buffer.write_u8(*light).unwrap();
            }
        }
        //let time_3 = ::time::now();

        if skylight {
            for section in &added_sections {
                for light in &section.borrow_skylight_data()[..] {
                    buffer.write_u8(*light).unwrap();
                }
            }
        }

        if entire_chunk {
            for biome in &self.biome[..] {
                buffer.write_u8(*biome).unwrap();
            }
        }
        //let time_4 = ::time::now();
        //println!("{:?} {:?} {:?}", (time_2 - time_1).num_microseconds(), (time_3 - time_2).num_microseconds(), (time_4 - time_3).num_microseconds());
        
        (section_bitmask, byte_size)
    }
}

impl Default for Chunk {
    fn default() -> Chunk {
        Chunk {
            sections: [ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ChunkSection::default(), ],
            biome: [0; BIOME_BUF_LEN],
        }
    }
}
