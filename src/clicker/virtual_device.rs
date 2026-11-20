use evdev::uinput::VirtualDeviceBuilder;
use evdev::{AttributeSet, EventType, InputEvent, Key};
use std::thread;
use std::time::Duration;

pub struct VirtualMouse {
    device: evdev::uinput::VirtualDevice,
}



impl VirtualMouse {
    
    pub fn new() -> Result<Self, std::io::Error> {
        let mut keys = AttributeSet::new();
        keys.insert(Key::BTN_LEFT);
        keys.insert(Key::BTN_RIGHT);
        keys.insert(Key::BTN_MIDDLE);
        keys.insert(Key::KEY_F);
        keys.insert(Key::KEY_SPACE);
        keys.insert(Key::KEY_W);

        let device = VirtualDeviceBuilder::new()?
            .name("Virtual Fast Clicker")
            .with_keys(&keys)?
            .build()?;
        Ok(Self { device })
    }

    pub fn emit(&mut self, events: &[evdev::InputEvent]) -> Result<(), std::io::Error> {
        self.device.emit(events)
    }
}