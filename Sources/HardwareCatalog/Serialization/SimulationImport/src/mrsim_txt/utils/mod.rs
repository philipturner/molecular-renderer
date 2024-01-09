// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

use std::collections::HashMap;

use serde::{Deserialize, Deserializer};

pub fn parse_coordinates<'de, D>(deserializer: D) -> Result<HashMap<usize, Vec<i32>>, D::Error>
where
    D: Deserializer<'de>,
{
    let values: Vec<HashMap<usize, String>> = Deserialize::deserialize(deserializer)?;
    let mut coords_map = HashMap::new();
    for map in values {
        for (k, v) in map {
            let coords: Vec<i32> = parse_space_separated_ints(&v)
                .map_err(|e| serde::de::Error::custom(format!("{}", e)))?;
            coords_map.insert(k, coords);
        }
    }
    Ok(coords_map)
}

pub fn deserialize_space_separated_ints<'de, D>(deserializer: D) -> Result<Vec<i32>, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    parse_space_separated_ints(&s).map_err(|e| serde::de::Error::custom(format!("{}", e)))
}

fn parse_space_separated_ints(s: &str) -> Result<Vec<i32>, std::num::ParseIntError> {
    s.split_whitespace()
        .map(|part| part.parse::<i32>())
        .collect()
}
