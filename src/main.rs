mod clicker;

use clicker::autoclicker::start_clicker_worker;
use clicker::virtual_device::VirtualMouse;
use evdev::{enumerate, Device, Key};
use qtbridge::{qobject, QApp};
use std::os::fd::AsRawFd;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU16, AtomicU64, AtomicU8, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

fn set_device_nonblocking(dev: &Device, nonblocking: bool) -> std::io::Result<()> {
    let fd = dev.as_raw_fd();
    unsafe {
        let flags = libc::fcntl(fd, libc::F_GETFL);
        if flags < 0 {
            return Err(std::io::Error::last_os_error());
        }
        let new_flags = if nonblocking {
            flags | libc::O_NONBLOCK
        } else {
            flags & !libc::O_NONBLOCK
        };
        if libc::fcntl(fd, libc::F_SETFL, new_flags) < 0 {
            return Err(std::io::Error::last_os_error());
        }
    }
    Ok(())
}

fn open_nonblocking_device(path: &PathBuf) -> Option<Device> {
    match Device::open(path) {
        Ok(dev) => {
            if let Err(e) = set_device_nonblocking(&dev, true) {
                eprintln!("Błąd ustawiania non-blocking dla {path:?}: {e}");
            }
            Some(dev)
        }
        Err(e) => {
            eprintln!("Nie udało się otworzyć {path:?}: {e}");
            None
        }
    }
}

pub struct Backend {
    is_running: Arc<AtomicBool>,
    interval_ms: Arc<AtomicU64>,
    started: AtomicBool,
    click_key_code: Arc<AtomicU16>,
    listen_key_code: Arc<AtomicU16>,
    capture_mode: Arc<AtomicU8>,
    capture_device_path: Arc<Mutex<PathBuf>>,
    listen_device_path: Arc<Mutex<PathBuf>>,
}

impl Default for Backend {
    fn default() -> Self {
        let paths: Vec<PathBuf> = enumerate().map(|(path, _)| path).collect();
        let mouse_path = paths
            .iter()
            .find(|p| p.to_string_lossy().ends_with("event3"))
            .cloned()
            .or_else(|| paths.first().cloned())
            .unwrap_or_else(|| PathBuf::from("/dev/input/event3"));

        Self {
            is_running: Arc::new(AtomicBool::new(false)),
            interval_ms: Arc::new(AtomicU64::new(100)),
            started: AtomicBool::new(false),
            click_key_code: Arc::new(AtomicU16::new(Key::BTN_LEFT.code())),
            listen_key_code: Arc::new(AtomicU16::new(Key::BTN_EXTRA.code())),
            capture_mode: Arc::new(AtomicU8::new(0)),
            capture_device_path: Arc::new(Mutex::new(mouse_path.clone())),
            listen_device_path: Arc::new(Mutex::new(mouse_path)),
        }
    }
}

#[qobject(Singleton)]
impl Backend {
    #[qslot]
    fn init_worker(&self) {
        if self.started.swap(true, Ordering::SeqCst) {
            return;
        }

        // Kopie dla wątku klikera (uinput)
        let is_running_clicker = Arc::clone(&self.is_running);
        let click_key_clicker = Arc::clone(&self.click_key_code);
        let interval_clicker = Arc::clone(&self.interval_ms);

        // Kopie dla wątku hotkeya start/stop
        let is_running_hotkey = Arc::clone(&self.is_running);
        let listen_key_hotkey = Arc::clone(&self.listen_key_code);
        let capture_mode_hotkey = Arc::clone(&self.capture_mode);
        let listen_device_hotkey = Arc::clone(&self.listen_device_path);

        // Kopie dla wątku przechwytywania klawisza
        let click_key_capture = Arc::clone(&self.click_key_code);
        let listen_key_capture = Arc::clone(&self.listen_key_code);
        let capture_mode_capture = Arc::clone(&self.capture_mode);
        let capture_device_capture = Arc::clone(&self.capture_device_path);

        // 1. Wątek klikera (uinput)
        thread::spawn(move || {
            let vmouse = match VirtualMouse::new() {
                Ok(m) => m,
                Err(e) => {
                    eprintln!("Błąd tworzenia VirtualMouse: {e}");
                    return;
                }
            };

            start_clicker_worker(vmouse, is_running_clicker, click_key_clicker, interval_clicker);
        });

        // 2. Wątek nasłuchujący hotkeya start/stop na listen_device_path
        thread::spawn(move || {
            let mut active_path = listen_device_hotkey.lock().unwrap().clone();
            let mut device_opt = open_nonblocking_device(&active_path);
            if let Some(ref dev) = device_opt {
                println!(
                    "[HOTKEY] Nasłuchuję na: {} ({active_path:?})",
                    dev.name().unwrap_or("Nieznane")
                );
            }

            loop {
                let desired_path = listen_device_hotkey.lock().unwrap().clone();
                if desired_path != active_path {
                    active_path = desired_path;
                    device_opt = open_nonblocking_device(&active_path);
                    if let Some(ref dev) = device_opt {
                        println!(
                            "[HOTKEY] Przełączono na: {} ({active_path:?})",
                            dev.name().unwrap_or("Nieznane")
                        );
                    }
                }

                if let Some(dev) = device_opt.as_mut() {
                    match dev.fetch_events() {
                        Ok(events) => {
                            if capture_mode_hotkey.load(Ordering::SeqCst) == 0 {
                                for event in events {
                                    if event.event_type() == evdev::EventType::KEY
                                        && event.value() == 1
                                        && event.code() == listen_key_hotkey.load(Ordering::Relaxed)
                                    {
                                        let new_state = !is_running_hotkey.load(Ordering::Relaxed);
                                        is_running_hotkey.store(new_state, Ordering::Relaxed);
                                        println!(
                                            "Autoclicker (HOTKEY): {}",
                                            if new_state { "WŁĄCZONY" } else { "WYŁĄCZONY" }
                                        );
                                    }
                                }
                            }
                        }
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            thread::sleep(Duration::from_millis(10));
                        }
                        Err(e) => {
                            eprintln!("[HOTKEY] Błąd odczytu {active_path:?}: {e}");
                            thread::sleep(Duration::from_millis(50));
                        }
                    }
                } else {
                    thread::sleep(Duration::from_millis(100));
                }
            }
        });

        // 3. Wątek przechwytywania nowego klawisza/przycisku na capture_device_path
        thread::spawn(move || {
            let mut active_path = capture_device_capture.lock().unwrap().clone();
            let mut device_opt = open_nonblocking_device(&active_path);
            if let Some(ref dev) = device_opt {
                println!(
                    "[CAPTURE] Urządzenie przechwytywania: {} ({active_path:?})",
                    dev.name().unwrap_or("Nieznane")
                );
            }

            loop {
                let desired_path = capture_device_capture.lock().unwrap().clone();
                if desired_path != active_path {
                    active_path = desired_path;
                    device_opt = open_nonblocking_device(&active_path);
                    if let Some(ref dev) = device_opt {
                        println!(
                            "[CAPTURE] Przełączono na: {} ({active_path:?})",
                            dev.name().unwrap_or("Nieznane")
                        );
                    }
                }

                let mode = capture_mode_capture.load(Ordering::SeqCst);
                if mode == 0 {
                    thread::sleep(Duration::from_millis(20));
                    continue;
                }

                if let Some(dev) = device_opt.as_mut() {
                    match dev.fetch_events() {
                        Ok(events) => {
                            for event in events {
                                if event.event_type() == evdev::EventType::KEY && event.value() == 1
                                {
                                    let code = event.code();
                                    let current_mode = capture_mode_capture.swap(0, Ordering::SeqCst);
                                    if current_mode == 0 {
                                        continue;
                                    }

                                    if code == Key::KEY_ESC.code() {
                                        println!("[CAPTURE] Anulowano przechwytywanie (ESC).");
                                    } else if current_mode == 1 {
                                        click_key_capture.store(code, Ordering::Relaxed);
                                        println!("[CAPTURE] Nowy przycisk klikania: {code}");
                                        break;
                                    } else if current_mode == 2 {
                                        listen_key_capture.store(code, Ordering::Relaxed);
                                        println!("[CAPTURE] Nowy hotkey: {code}");
                                        break;
                                    }
                                }
                            }
                        }
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            thread::sleep(Duration::from_millis(10));
                        }
                        Err(e) => {
                            eprintln!("[CAPTURE] Błąd odczytu {active_path:?}: {e}");
                            thread::sleep(Duration::from_millis(50));
                        }
                    }
                } else {
                    thread::sleep(Duration::from_millis(100));
                }
            }
        });
    }

    #[qslot]
    fn device_names(&self) -> Vec<String> {
        enumerate()
            .map(|(path, dev)| {
                let name = dev.name().unwrap_or("Nieznane urządzenie");
                format!("{name} ({})", path.display())
            })
            .collect()
    }

    #[qslot]
    fn select_device_by_label(&self, label: String) {
        for (path, dev) in enumerate() {
            let name = dev.name().unwrap_or("Nieznane urządzenie");
            let candidate = format!("{name} ({})", path.display());
            if candidate == label {
                println!("Wybrano urządzenie przechwytywania: {candidate} -> {path:?}");
                *self.capture_device_path.lock().unwrap() = path;
                return;
            }
        }
        eprintln!("Nie znaleziono urządzenia dla etykiety: {label}");
    }

    #[qslot]
    fn set_listen_device_to_selected(&self) {
        let cap = self.capture_device_path.lock().unwrap().clone();
        println!("Ustawiono urządzenie hotkeya na: {cap:?}");
        *self.listen_device_path.lock().unwrap() = cap;
    }

    #[qslot]
    fn is_capturing(&self) -> bool {
        self.capture_mode.load(Ordering::SeqCst) != 0
    }

    #[qslot]
    fn click_key_code_val(&self) -> u16 {
        self.click_key_code.load(Ordering::Relaxed)
    }

    #[qslot]
    fn listen_key_code_val(&self) -> u16 {
        self.listen_key_code.load(Ordering::Relaxed)
    }

    #[qslot]
    fn is_running_val(&self) -> bool {
        self.is_running.load(Ordering::Relaxed)
    }

    #[qslot]
    fn capture_mode_val(&self) -> u8 {
        self.capture_mode.load(Ordering::SeqCst)
    }

    #[qslot]
    fn toggle_clicker(&self) {
        let new_state = !self.is_running.load(Ordering::Relaxed);
        self.is_running.store(new_state, Ordering::Relaxed);
        println!(
            "Autoclicker (UI): {}",
            if new_state { "WŁĄCZONY" } else { "WYŁĄCZONY" }
        );
    }

    #[qslot]
    fn arm_capture_click_key_code(&self) {
        self.is_running.store(false, Ordering::Relaxed);
        self.capture_mode.store(1, Ordering::SeqCst);
    }

    #[qslot]
    fn arm_capture_listen_key_code(&self) {
        self.is_running.store(false, Ordering::Relaxed);
        self.capture_mode.store(2, Ordering::SeqCst);
    }

    #[qslot]
    fn cancel_capture(&self) {
        self.capture_mode.store(0, Ordering::SeqCst);
    }

    #[qslot]
    fn set_interval_ms(&self, ms: u64) {
        self.interval_ms.store(ms.max(1), Ordering::Relaxed);
    }

    #[qslot]
    fn set_running(&self, running: bool) {
        self.is_running.store(running, Ordering::Relaxed);
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    QApp::new()
        .register::<Backend>()
        .load_qml(include_bytes!("qml/Main.qml"))
        .run();
    Ok(())
}