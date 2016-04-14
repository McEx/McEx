
#[derive(Copy, Clone)]
#[repr(C, packed)]
pub struct BlockData {
    value: u16,
}
impl BlockData {
    pub fn new(id: u16, meta: u8) -> BlockData {
        BlockData {
            value: (id << 4) | (meta as u16 & 15),
        }
    }
    pub fn new_raw(value: u16) -> BlockData {
        BlockData {
            value: value
        }
    }
    pub fn get_value(&self) -> &u16 {
        &self.value
    }
    pub fn set_value_raw(&mut self, value: u16) {
        self.value = value;
    }
    pub fn set_value(&mut self, id: u16, meta: u8) {
        self.set_value_raw((id << 4) | (meta as u16 & 15))
    }
    pub fn is_air(&self) -> bool {
        self.value == 0
    }

    pub fn get_id(&self) -> u16 {
        self.value >> 4
    }
    pub fn get_meta(&self) -> u8 {
        (self.value & 15) as u8
    }
}
impl Default for BlockData {
    fn default() -> BlockData {
        BlockData {
            value: 0
        }
    }
}
