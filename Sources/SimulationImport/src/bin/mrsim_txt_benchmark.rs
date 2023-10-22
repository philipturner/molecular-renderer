// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

use anyhow::Result;
use colored::*;
use rand::Rng;
use simulation_import::mrsim_txt::definitions::ParsedData;
use std::env;
use std::fs;
use std::time::Instant;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let mut args_iter = args.iter();

    if args.len() < 2 {
        eprintln!("Usage: mrsim_txt_benchmark(.exe) <file_path> [--frames=frame1,frame2,...] [--atoms=atom1,atom2,...]");
        std::process::exit(1);
    }

    let _program_name = args_iter.next().unwrap(); // Skip program name in argument list
    let file_path = args_iter.next().unwrap();
    println!("{}", format!("Loading file: {}...", file_path).green());
    println!();

    // Fetch optional frame and atom arguments
    let frames_arg = args_iter.find(|&arg| arg.starts_with("--frames="));
    let atoms_arg = args_iter.find(|&arg| arg.starts_with("--atoms="));

    let start_load = Instant::now();
    let content = fs::read_to_string(file_path)?;
    let duration_load = start_load.elapsed();

    // Parse the content and populate raw structures
    let start_parse = Instant::now();
    let mut parsed_data = ParsedData::new(&content).unwrap();
    let duration_parse = start_parse.elapsed();

    // Calculate absolute positions
    let start_calculation = Instant::now();
    parsed_data.calculate_positions();
    let duration_calculation = start_calculation.elapsed();

    let parsed_result = parsed_data.data();
    let diagnostics = parsed_data.diagnostics();

    println!(
        "{}",
        format!("Loaded file in: {:?}", duration_load).yellow()
    );
    for diagnostic in diagnostics.iter() {
        println!("{}", diagnostic.yellow());
    }
    println!(
        "{}",
        format!("Calculated positions in: {:?}", duration_calculation).yellow()
    );
    println!(
        "{}",
        format!("Total decoding time: {:?}", duration_parse).yellow()
    );

    let cluster_size = parsed_result.header().frame_cluster_size();
    let spatial_resolution = *parsed_result.header().spatial_resolution();

    // Calculate the total number of available frames and atoms
    let max_frames = parsed_result.header().frame_count();
    let max_atoms = if let Some(first_cluster) = parsed_result.clusters().values().next() {
        first_cluster.atoms().x_coordinates().len()
    } else {
        0
    };

    let predefined_frames: Vec<usize> = frames_arg
        .map(|frames| {
            frames[9..]
                .split(',')
                .filter_map(|s| s.parse().ok())
                .collect()
        })
        .unwrap_or_else(|| generate_random_indices(10, 0, max_frames - 1));

    let predefined_atoms: Vec<usize> = atoms_arg
        .map(|atoms| {
            atoms[8..]
                .split(',')
                .filter_map(|s| s.parse().ok())
                .collect()
        })
        .unwrap_or_else(|| generate_random_indices(5, 0, max_atoms)); // Here we simply use 1 as the "cluster size" for atoms

    for &frame in &predefined_frames {
        // Calculate the cluster index and relative frame index based on the provided frame number and cluster size.
        let cluster_idx = frame / cluster_size;
        let relative_frame_idx = frame % cluster_size;

        if let Some(cluster) = parsed_result.clusters().get(&cluster_idx) {
            let atoms = &cluster.atoms();
            println!();
            println!("Frame {}", frame);
            println!(
                "- timestamp: {:.3} ps",
                frame as f64 * parsed_result.header().frame_time() * 1e-3
            );

            for &atom_idx in &predefined_atoms {
                let x_vec = atoms.x_coordinates().get(&atom_idx).unwrap();
                let y_vec = atoms.y_coordinates().get(&atom_idx).unwrap();
                let z_vec = atoms.z_coordinates().get(&atom_idx).unwrap();

                if relative_frame_idx < x_vec.len() {
                    let element = atoms.elements()[atom_idx];
                    let flag = atoms.flags()[atom_idx];

                    // Convert the coordinates using the spatial resolution
                    let x_pos =
                        x_vec[relative_frame_idx] as f32 * spatial_resolution as f32 / 1000.0;
                    let y_pos =
                        y_vec[relative_frame_idx] as f32 * spatial_resolution as f32 / 1000.0;
                    let z_pos =
                        z_vec[relative_frame_idx] as f32 * spatial_resolution as f32 / 1000.0;

                    println!(
                        " - atom {}: {:.3} {:.3} {:.3} {} {}",
                        atom_idx, x_pos, y_pos, z_pos, element, flag
                    );
                }
            }
        }
    }

    Ok(())
}

fn generate_random_indices(n: usize, min: usize, max: usize) -> Vec<usize> {
    let mut all_possible_indices: Vec<usize> = (min..max).collect();
    let mut rng = rand::thread_rng();
    let mut chosen_indices = Vec::new();

    for _ in 0..n {
        if all_possible_indices.is_empty() {
            break; // Can't select more unique indices
        }

        let idx = rng.gen_range(0..all_possible_indices.len());
        chosen_indices.push(all_possible_indices[idx]);

        // Remove the chosen index to ensure uniqueness
        all_possible_indices.swap_remove(idx);
    }

    chosen_indices.sort();
    chosen_indices
}
