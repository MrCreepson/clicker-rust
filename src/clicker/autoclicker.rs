use crate::clicker::virtual_device::VirtualMouse;
use evdev::{EventType, InputEvent};
use std::sync::atomic::{AtomicBool, AtomicU16, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

pub fn start_clicker_worker(mut vmouse: VirtualMouse, running_flag: Arc<AtomicBool>, click_key_code: Arc<AtomicU16>, interval_ms: Arc<AtomicU64>) {
    thread::spawn(move || {
        let mut next_click = Instant::now();
        let syn_evt = InputEvent::new(EventType::SYNCHRONIZATION, 0, 0);

        let mut last_code = click_key_code.load(Ordering::Relaxed);
        let mut down_evt = InputEvent::new(EventType::KEY, last_code, 1);
        let mut up_evt   = InputEvent::new(EventType::KEY, last_code, 0);
        
        let mut last_ms = interval_ms.load(Ordering::Relaxed);
        let mut interval = Duration::from_millis(last_ms);

        
        loop {
            if running_flag.load(Ordering::Relaxed) {
                let code = click_key_code.load(Ordering::Relaxed);
                if code != last_code {
                    last_code = code;
                    down_evt = InputEvent::new(EventType::KEY, code, 1);
                    up_evt   = InputEvent::new(EventType::KEY, code, 0);
                }

                let ms = interval_ms.load(Ordering::Relaxed).max(1);
                if ms != last_ms {
                    last_ms = ms;
                    interval = Duration::from_millis(ms);
                }
                
                
                let _ = vmouse.emit(&[down_evt, syn_evt, up_evt, syn_evt]);

                next_click += interval;
                let now = Instant::now();
                if next_click > now {
                    let diff = next_click - now;
                    if diff > Duration::from_millis(2) {
                        thread::sleep(diff - Duration::from_millis(1));
                    }
                    while Instant::now() < next_click {
                        std::hint::spin_loop();
                    }
                } else {
                    next_click = now;
                }
            } else {
                thread::sleep(Duration::from_millis(10));
                next_click = Instant::now();
            }
        }
    });
}