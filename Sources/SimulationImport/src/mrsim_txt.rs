// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

pub mod definitions;
pub mod utils;

use crate::mrsim_txt::definitions::{
    Atoms, Calculated, Diagnostics, FrameCluster, Header, Metadata, MrSimTxt, ParsedData,
};

use rayon::prelude::{IntoParallelIterator, ParallelIterator};
use serde_yaml;
use std::{collections::HashMap, time::Instant};

impl MrSimTxt {
    pub fn specification(&self) -> Option<&Vec<String>> {
        self.specification.as_ref()
    }
    pub fn header(&self) -> &Header {
        &self.header
    }
    pub fn metadata(&self) -> Option<&Metadata> {
        self.metadata.as_ref()
    }
    pub fn clusters(&self) -> &HashMap<usize, FrameCluster> {
        &self.clusters
    }
    pub fn calculated(&self) -> &Calculated {
        &self.calculated
    }
}

// This is the core abstraction that should be used by any external application
impl ParsedData {
    pub fn data(&self) -> &MrSimTxt {
        &self.data
    }
    pub fn diagnostics(&self) -> &Diagnostics {
        &self.diagnostics
    }
    pub fn new(yaml_data: &str) -> Result<Self, serde_yaml::Error> {
        let (parsed_data, diagnostics) = parse(yaml_data)?;
        Ok(ParsedData {
            data: parsed_data,
            diagnostics,
            has_calculated_coordinates: false,
        })
    }
    pub fn discard_original_clusters(&mut self) {
        if self.has_calculated_coordinates {
            self.data.clusters.clear();
        }
    }
    pub fn calculate_positions(&mut self) {
        // iterate over all frame clusters in data.clusters and calculate the positions. Each frame cluster first frame contains the absolute positions,
        // the rest contains the deltas relative to the previous frame. The outcome of this function must be populating the calculated structure
        // with the absolute positions for each frame cluster.
        let first_cluster = self.data.clusters.get(&1).unwrap();
        let atoms = first_cluster.atoms();
        let x_coordinates = atoms.x_coordinates();
        let y_coordinates = atoms.y_coordinates();
        let z_coordinates = atoms.z_coordinates();

        let mut x: HashMap<usize, Vec<i32>> = HashMap::new();
        let mut y: HashMap<usize, Vec<i32>> = HashMap::new();
        let mut z: HashMap<usize, Vec<i32>> = HashMap::new();

        for (k, v) in x_coordinates.iter() {
            let mut new_frame = Vec::with_capacity(v.len());
            for &value in v.iter() {
                new_frame.push(value + 1);
            }
            x.insert(*k, new_frame);
        }
        for (k, v) in y_coordinates.iter() {
            let mut new_frame = Vec::with_capacity(v.len());
            for &value in v.iter() {
                new_frame.push(value + 2);
            }
            y.insert(*k, new_frame);
        }
        for (k, v) in z_coordinates.iter() {
            let mut new_frame = Vec::with_capacity(v.len());
            for &value in v.iter() {
                new_frame.push(value + 3);
            }
            z.insert(*k, new_frame);
        }

        self.data.calculated.x = x;
        self.data.calculated.y = y;
        self.data.calculated.z = z;
        self.data.calculated.elements = atoms.elements().clone();
        self.data.calculated.flags = atoms.flags().clone();

        self.has_calculated_coordinates = true;
    }
}

impl Header {
    pub fn frame_time(&self) -> &f64 {
        &self.frame_time
    }
    pub fn spatial_resolution(&self) -> &f64 {
        &self.spatial_resolution
    }
    pub fn uses_checkpoints(&self) -> &bool {
        &self.uses_checkpoints
    }
    pub fn frame_count(&self) -> &usize {
        &self.frame_count
    }
    pub fn frame_cluster_size(&self) -> &usize {
        &self.frame_cluster_size
    }
}

impl Calculated {
    pub fn x(&self) -> &HashMap<usize, Vec<i32>> {
        &self.x
    }
    pub fn y(&self) -> &HashMap<usize, Vec<i32>> {
        &self.y
    }
    pub fn z(&self) -> &HashMap<usize, Vec<i32>> {
        &self.z
    }
    pub fn elements(&self) -> &Vec<i32> {
        &self.elements
    }
    pub fn flags(&self) -> &Vec<i32> {
        &self.flags
    }
}

impl FrameCluster {
    pub fn frame_start(&self) -> &usize {
        &self.frame_start
    }
    pub fn frame_end(&self) -> &usize {
        &self.frame_end
    }
    pub fn metadata(&self) -> &Option<HashMap<String, Vec<f64>>> {
        &self.metadata
    }
    pub fn atoms(&self) -> &Atoms {
        &self.atoms
    }
}

impl Atoms {
    pub fn x_coordinates(&self) -> &HashMap<usize, Vec<i32>> {
        &self.x_coordinates
    }
    pub fn y_coordinates(&self) -> &HashMap<usize, Vec<i32>> {
        &self.y_coordinates
    }
    pub fn z_coordinates(&self) -> &HashMap<usize, Vec<i32>> {
        &self.z_coordinates
    }
    pub fn elements(&self) -> &Vec<i32> {
        &self.elements
    }
    pub fn flags(&self) -> &Vec<i32> {
        &self.flags
    }
}

impl std::fmt::Debug for Atoms {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Atoms")
            .field("x_coordinates count", &self.x_coordinates.len())
            .field("y_coordinates count", &self.y_coordinates.len())
            .field("z_coordinates count", &self.z_coordinates.len())
            .field("elements count", &self.elements.len())
            .field("flags count", &self.flags.len())
            .finish()
    }
}

impl Diagnostics {
    pub fn new() -> Self {
        Self::default()
    }
    pub fn add(&mut self, message: String) {
        self.messages.push(message);
    }
    // Provide a method to get an iterator over the messages
    pub fn iter(&self) -> std::slice::Iter<'_, String> {
        self.messages.iter()
    }
    // Keeping this method in case you still want direct access to the Vec
    pub fn messages(&self) -> &Vec<String> {
        &self.messages
    }
}

// This method splits a YAML string into non-cluster and cluster sections
// Individual cluster sections are used later to parallelize the parsing process
fn split_yaml(yaml: &str) -> (String, Vec<String>) {
    let mut non_cluster = String::new();
    let mut clusters = Vec::new();
    let mut current_cluster = String::new();
    let mut is_inside_cluster = false;

    for line in yaml.lines() {
        if line.starts_with("frame cluster ") {
            if !current_cluster.is_empty() {
                clusters.push(current_cluster.clone());
                current_cluster.clear();
            }
            is_inside_cluster = true;
        }

        if is_inside_cluster {
            current_cluster.push_str(line);
            current_cluster.push('\n');
        } else {
            non_cluster.push_str(line);
            non_cluster.push('\n');
        }
    }

    if !current_cluster.is_empty() {
        clusters.push(current_cluster);
    }

    (non_cluster, clusters)
}

fn frame_clusters_deserializer(
    map: HashMap<String, FrameCluster>,
) -> Result<HashMap<usize, FrameCluster>, serde_yaml::Error> {
    let mut ordered_map = HashMap::new();

    for (key, value) in map.into_iter() {
        if let Some(cluster_idx) = key.strip_prefix("frame cluster ") {
            if let Ok(idx) = cluster_idx.parse::<usize>() {
                ordered_map.insert(idx, value);
            } else {
                return Err(serde::de::Error::custom(format!(
                    "Unexpected frame cluster key: {}",
                    key
                )));
            }
        }
    }

    Ok(ordered_map)
}

// Main parsing function
// Converts a given YAML string into MrSimTxt and Diagnostics structures
// It uses clusters' parallel processing for efficient parsing of large datasets
pub fn parse(yaml: &str) -> Result<(MrSimTxt, Diagnostics), serde_yaml::Error> {
    let mut diagnostics = Diagnostics::new();

    let start = Instant::now();

    let (non_cluster, clusters) = split_yaml(yaml);

    let preprocessed_duration = start.elapsed();

    diagnostics.add(format!(
        "Preprocessed text in: {}ms",
        preprocessed_duration.as_millis()
    ));

    let header_start = Instant::now();
    // Parse non-cluster part into a partial MrSimTxt structure
    let mut mr_sim_txt: MrSimTxt = serde_yaml::from_str(&non_cluster)?;
    let header_duration = header_start.elapsed();

    diagnostics.add(format!(
        "Parsed header in: {}ms",
        header_duration.as_millis()
    ));

    // This is where all parsed clusters would be stored
    let mut all_clusters: HashMap<usize, FrameCluster> = HashMap::new();

    let cluster_start = Instant::now();
    let clusters_data: Result<Vec<HashMap<String, FrameCluster>>, serde_yaml::Error> = clusters
        .into_par_iter()
        .map(|cluster_yaml| serde_yaml::from_str::<HashMap<String, FrameCluster>>(&cluster_yaml))
        .collect::<Result<Vec<_>, _>>();

    let cluster_duration = cluster_start.elapsed();

    diagnostics.add(format!(
        "Parsed clusters in: {} ms",
        cluster_duration.as_millis()
    ));

    let thread_count = rayon::current_num_threads();
    diagnostics.add(format!("Using {} threads", thread_count));

    match clusters_data {
        Ok(cluster_maps) => {
            for map in cluster_maps {
                // Convert each cluster map into the desired format using your deserializer logic
                let ordered_map = frame_clusters_deserializer(map)?;

                // Merge the ordered_map into the all_clusters map
                all_clusters.extend(ordered_map);
            }
        }
        Err(e) => return Err(e),
    }

    // Assign the combined clusters map to the main structure
    mr_sim_txt.clusters = all_clusters;

    Ok((mr_sim_txt, diagnostics))
}
