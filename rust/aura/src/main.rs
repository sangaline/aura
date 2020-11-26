//! The Aura Package Manager.

use ::log::debug;
use alpm::Alpm;
use aura::command::*;
use aura::error::Error;
use aura::flags::{SubCmd, AURA_GLOBALS};
use aura_arch as arch;
use clap::Clap;
use simplelog::Config;
use simplelog::TermLogger;
use simplelog::TerminalMode;
use std::path::Path;
use std::process::Command;

fn main() -> Result<(), Error> {
    // Parse all CLI input. Exits immediately if invalid input is given.
    let args = aura::flags::Args::parse();

    // Activate the logger.
    if let Some(l) = args.log_level {
        TermLogger::init(l, Config::default(), TerminalMode::Mixed).map_err(Error::Log)?;
    }

    // Establish the language strings to be used.
    let lang = args.language();
    let fll = aura::localization::load(lang).map_err(Error::I18n)?;

    // Establish common file paths.
    let log_path: &Path = args
        .logfile
        .as_ref()
        .map(|p| Path::new(p))
        .unwrap_or_else(|| Path::new(arch::DEFAULT_LOG));
    let cache_path: &Path = args
        .cachedir
        .as_ref()
        .map(|p| Path::new(p))
        .unwrap_or_else(|| Path::new(arch::DEFAULT_CACHE));

    let mut alpm = Alpm::new(
        args.root.unwrap_or_else(|| arch::DEFAULT_ROOT.to_string()),
        args.dbpath.unwrap_or_else(|| arch::DEFAULT_DB.to_string()),
    )
    .map_err(Error::Alpm)?;

    match args.subcmd {
        // --- Pacman Commands --- //
        SubCmd::Database(_) => pacman()?,
        SubCmd::Files(_) => pacman()?,
        SubCmd::Query(_) => pacman()?,
        SubCmd::Remove(_) => pacman()?,
        SubCmd::DepTest(_) => pacman()?,
        SubCmd::Upgrade(_) => pacman()?,
        SubCmd::Sync(_) => pacman()?,
        // --- AUR Packages --- //
        SubCmd::Aur(_) => unimplemented!(),
        SubCmd::Backup(_) => unimplemented!(),
        // --- The Package Cache --- //
        SubCmd::Cache(c) if c.search.is_some() => cache::search(cache_path, c.search.unwrap())?,
        SubCmd::Cache(_) => unimplemented!(),
        // --- Logs --- //
        SubCmd::Log(l) if l.search.is_some() => log::search(log_path, l.search.unwrap())?,
        SubCmd::Log(l) if !l.info.is_empty() => log::info(fll, log_path, l.info),
        SubCmd::Log(_) => log::view(log_path)?,
        // --- Orphan Packages --- //
        SubCmd::Orphans(o) if o.abandon => orphans::remove(&mut alpm, fll)?,
        SubCmd::Orphans(o) if !o.adopt.is_empty() => orphans::adopt(&alpm, fll, o.adopt)?,
        SubCmd::Orphans(_) => orphans::list(&alpm),
        // --- PKGBUILD Analysis --- //
        SubCmd::Analysis(_) => unimplemented!(),
        // --- Configuration --- //
        SubCmd::Conf(c) if c.pacman => conf::pacman_conf(c)?,
        SubCmd::Conf(c) if c.aura => unimplemented!(),
        SubCmd::Conf(c) if c.makepkg => conf::makepkg_conf()?,
        SubCmd::Conf(_) => unimplemented!(),
        // --- Statistics --- //
        SubCmd::Stats(s) if s.localization => stats::localization()?,
        SubCmd::Stats(s) if s.heavy => stats::heavy_packages(&alpm),
        SubCmd::Stats(_) => unimplemented!(),
        // --- Other --- //
        SubCmd::Lang(_) => misc::languages(),
    }

    Ok(())
}

/// Run a Pacman command.
fn pacman() -> Result<(), Error> {
    let mut raws: Vec<String> = std::env::args()
        .skip(1)
        .filter(|a| !(AURA_GLOBALS.contains(&a.as_str()) || a.starts_with("--log-level=")))
        .collect();

    // Special consideration for split cases like `--log-level debug`.
    if let Some(ix) = raws
        .iter()
        .enumerate()
        // TODO Use `bool::then` once it soon stabilizes.
        .find_map(|(i, v)| if v == "--log-level" { Some(i) } else { None })
    {
        raws.remove(ix); // --log-level
        raws.remove(ix); // Its argument.
    }

    debug!("Passing to Pacman: {:?}", raws);

    match Command::new("pacman").args(raws).status() {
        Err(e) => Err(Error::IO(e)),
        Ok(es) if es.success() => Ok(()),
        Ok(_) => Err(Error::PacmanError),
    }
}
