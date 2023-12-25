use std::time::Instant;
use std::fmt::Write;
use std::sync::{Arc, Mutex};
use std::thread;

// MARK: - Utilities

fn start_error(
  start: &str,
  sequence: &str,
  line: u32,
  function: &str
) -> ! {
  panic!(
    "'{}' is not the start of '{}'.",
    start, sequence, file = function, line = line);
}

fn assert_expected_prefix(prefix: &str, text: &str) {
  if !text.starts_with(prefix) {
    start_error(prefix, text);
  }
}

fn remove_expected_prefix(prefix: &str, text: &mut &str) {
  assert_expected_prefix(prefix, text);
  *text = &text[prefix.len()..];
}

fn remove_including(prefix: &str, text: &mut &str) {
  while text.starts_with(prefix) {
    *text = &text[prefix.len()..];
  }
}

fn remove_excluding(prefix: &str, text: &mut &str) {
  while !text.starts_with(prefix) {
    *text = &text[prefix.len()..];
    if text.is_empty() {
      break;
    }
  }
}

fn extract_excluding(prefix: &str, text: &mut &str) -> String {
  let mut output = String::new();
  while !text.starts_with(prefix) {
    output.push_str(&text[..prefix.len()]);
    *text = &text[prefix.len()..];
    if text.is_empty() {
      break;
    }
  }
  output
}

fn large_integer_repr(number: i32) -> String {
  if number < 1_000 {
    number.to_string()
  } else if number < 1_000_000 {
    let radix = 1_000;
    format!("{}.{} thousand", number / radix, number % radix / 100)
  } else if number < 1_000_000_000 {
    let radix = 1_000_000;
    format!("{}.{} million", number / radix, number % radix / (radix / 10))
  } else if number < 1_000_000_000_000 {
    let radix = 1_000_000_000;
    format!("{}.{} billion", number / radix, number % radix / (radix / 10))
  } else {
    let radix = 1_000_000_000_000;
    format!("{}.{} trillion", number / radix, number % radix / (radix / 10))
  }
}

fn latency_repr<T: Into<f64>>(number: T) -> String {
  let number = (number.into() * 1e6).round() as i32; // microseconds
  if number < 1_000 {
    format!("{} µs", number)
  } else if number < 1_000_000 {
    let radix = 1_000;
    format!("{}.{} ms", number / radix, number % radix / (radix / 10))
  } else if number < 60 * 1_000_000 {
    let radix = 1_000_000;
    format!("{}.{} s", number / radix, number % radix / (radix /10))
  } else if number < 3_600 * 1_000_000 {
    let radix = 60 * 1_000_000;
    format!("{}.{} min",number/radix,number%radix/(radix/10))
}else{
let radix = 3_600 * 1_000_000;
format!("{}.{} hr",number/radix,number%radix/(radix/10))
}
}

let mut log=String::new();
fn log_checkpoint(message:&str,start:Instant,end:Instant){
let seconds=end.duration_since(start).as_secs_f64();
let mut str=String::new();
write!(&mut str,"{}:\x1b[0;33m{}\x1b[0m",message,latency_repr(seconds)).unwrap();
log.push_str(&str);
log.push('\n');
println!("{}",str);
}

// Data for multithreading.
let num_cores=num_cpus::get();
let queue=Arc::new(Mutex::new(Vec::new())); // A shared queue of tasks

use std::time::Instant;
use std::fs::File;
use std::io::Read;
use std::env;
use std::mem;

// MARK: - Header

let checkpoint0 = Instant::now(); // Store the current time
let file_path = env::args().nth(1).expect("No file path given"); // Get the file path from the command line arguments
let mut file = File::open(&file_path).expect(&format!("File not found at path: {}/{}", env::current_dir().unwrap().display(), file_path)); // Open the file or exit with an error message
let mut contents = String::new(); // Create an empty string to store the contents of the file
file.read_to_string(&mut contents).unwrap(); // Read the contents of the file as a string
let contents_buffer = contents.as_bytes(); // Get a slice of bytes from the string

let checkpoint1 = Instant::now(); // Store the current time
log_checkpoint(message="Loaded file in", start=checkpoint0, end=checkpoint1); // Print how much time it took to load the file

{
  let mut lines: Vec<&str>; // Create a mutable variable to store the lines as string slices
  if contents[..100].contains("\r") { // Check if the first 100 characters contain a carriage return character, which indicates Windows-style line endings
    // Remove \r on Windows.
    lines = contents.split("\r\n").collect(); // Split the string by "\r\n" and collect the slices into a vector
  } else {
    lines = contents.split("\n").collect(); // Split the string by "\n" and collect the slices into a vector
  }
}

// Assumes there are no comments in the bulk of the text.
let range_separator = lines.len().min(100); // Find the minimum of 100 and the number of lines
lines = lines[..range_separator].into_iter().filter(|line| { // Iterate over the first range_separator lines and filter out any line that
  !line.trim_start().starts_with("#") // starts with "#" after trimming leading whitespace
}).cloned().collect::<Vec<_>>() // clone the remaining slices and collect them into a vector
  + &lines[range_separator..]; // append the rest of the lines

fn assert_new_line(string: &str) { // Define a function to check if a string is empty
  if string != "" { // If the string is not empty
    start_error("", string); // Call the start_error function with an empty string and the given string
  }
}

let checkpoint2 = Instant::now(); // Store the current time
log_checkpoint(message="Preprocessed text in", start=checkpoint1, end=checkpoint2); // Print how much time it took to preprocess the text

assert_expected_prefix("specification:", lines[0]); // Check that the first line starts with "specification:"
remove_expected_prefix("  - https://github.com", &mut lines[1]); // Remove "  - https://github.com" from the second line
assert_new_line(lines[2]); // Check that the third line is empty

assert_expected_prefix("header:", lines[3]); // Check that the fourth line starts with "header:"
remove_expected_prefix("  frame time in femtoseconds: ", &mut lines[4]); // Remove "  frame time in femtoseconds: " from the fifth line
let frame_time_in_fs = lines[4].parse::<f64>().unwrap(); // Parse the fifth line as a floating-point number
remove_expected_prefix("  spatial resolution in approximate picometers: ", &mut lines[5]); // Remove "  spatial resolution in approximate picometers: " from the sixth line
let resolution_in_approx_pm = lines[5].parse::<f64>().unwrap(); // Parse the sixth line as a floating-point number

remove_expected_prefix("  uses checkpoints: ", &mut lines[6]); // Remove "  uses checkpoints: " from the seventh line
match lines[6] { // Match on the seventh line
  "false" => {}, // If it is "false", do nothing
  "true" => panic!("Checkpoints not recognized yet."), // If it is "true", panic with an error message
  _ => panic!("Error parsing {}", lines[6]), // Otherwise, panic with another error message
}

remove_expected_prefix("  frame count: ", &mut lines[7]); // Remove "  frame count: " from the eighth line
let frame_count = lines[7].parse::<usize>().unwrap(); // Parse the eighth line as an unsigned integer
remove_expected_prefix("  frame cluster size: ", &mut lines[8]); // Remove "  frame cluster size: " from the ninth line
let cluster_size = lines[8].parse::<usize>().unwrap(); // Parse the ninth line as an unsigned integer
assert_new_line(lines[9]); // Check that the tenth line is empty

assert_expected_prefix("metadata:", lines[10]); // Check that the eleventh line starts with "metadata:"
assert_new_line(lines[11]); // Check that the twelfth line is empty

use std::sync::{Arc, Mutex};
use std::thread;
use rayon::prelude::*;

// MARK: - Header

let checkpoint0 = Instant::now(); // Store the current time
let file_path = env::args().nth(1).expect("No file path given"); // Get the file path from the command line arguments
let mut file = File::open(&file_path).expect(&format!("File not found at path: {}/{}", env::current_dir().unwrap().display(), file_path)); // Open the file or exit with an error message
let mut contents = String::new(); // Create an empty string to store the contents of the file
file.read_to_string(&mut contents).unwrap(); // Read the contents of the file as a string
let contents_buffer = contents.as_bytes(); // Get a slice of bytes from the string

let checkpoint1 = Instant::now(); // Store the current time
log_checkpoint(message="Loaded file in", start=checkpoint0, end=checkpoint1); // Print how much time it took to load the file

#[cfg(feature = "release")]
{
  let mut new_line_positions: Vec<usize> = Vec::new(); // Create an empty vector to store the positions of new lines
  for (character_id, character) in contents_buffer.iter().enumerate() { // Iterate over each byte and its index in the buffer
    if *character == b'\n' { // If the byte is a newline character
      new_line_positions.push(character_id); // Push its index to the vector
    }
  }

  // Add an extra position for the last (non-omitted) subsequence.
  new_line_positions.push(contents.len());

  let mut _lines: Vec<String> = Vec::new(); // Create an empty vector to store the lines as strings
  let mut lines: Vec<&str> = Vec::new(); // Create an empty vector to store the lines as string slices

  {
    let is_windows = contents[..100].contains("\r"); // Check if the first 100 characters contain a carriage return character, which indicates Windows-style line endings
    let mut current_position = 0; // Initialize a variable to store the current position in the buffer
    let mut scratch = vec![0u8; 2]; // Create a vector of bytes with a capacity of 2 to use as a scratch buffer
    
    for position in new_line_positions { // Iterate over each position in the vector of new line positions
      let mut position_adjusted = position; // Initialize a variable to store the adjusted position
      if is_windows { // If using Windows-style line endings
        assert_eq!(contents_buffer[position - 1], b'\r', "Detected Windows-style line endings, but one of the lines didn't have a carriage return."); // Check that the previous byte is a carriage return character or panic with an error message
        position_adjusted -= 1; // Adjust the position by subtracting one
      }
      
      let num_characters = position_adjusted - current_position; // Calculate the number of characters in the line
      let num_zero_padded_characters = num_characters + 1; // Add one for zero padding
      if scratch.len() < num_zero_padded_characters { // If the scratch buffer is not large enough
        fn round_up_to_power_of_2(input: usize) -> usize { // Define a function to round up an integer to the next power of two
          1 << (mem::size_of::<usize>() * 8 - input.saturating_sub(1).leading_zeros() as usize)
        }
        let capacity = round_up_to_power_of_2(num_zero_padded_characters); // Calculate the capacity by rounding up to the next power of two
        scratch.resize(capacity, 0); // Resize the scratch buffer with zero padding
      }
      
      scratch[..num_characters].copy_from_slice(&contents_buffer[current_position..position_adjusted]); // Copy the bytes from the buffer to the scratch buffer
      scratch[num_characters] = b'\0'; // Add a zero byte at the end
      let line = unsafe { std::str::from_utf8_unchecked(&scratch[..num_zero_padded_characters]) }; // Convert the scratch buffer to a string slice without checking for validity (unsafe)
      _lines.push(line.to_owned()); // Push a copy of the string slice to the _lines vector
      lines.push(line); // Push a reference to the string slice to the lines vector
      
      current_position = position + 1; // Update the current position by adding one
    }
  }
}
#[cfg(not(feature = "release"))]
{
  let mut lines: Vec<&str>; // Create a mutable variable to store the lines as string slices
  if contents[..100].contains("\r") { // Check if the first 100 characters contain a carriage return character, which indicates Windows-style line endings
    // Remove \r on Windows.
    lines = contents.split("\r\n").collect(); // Split the string by "\r\n" and collect the slices into a vector
  } else {
    lines = contents.split("\n").collect(); // Split the string by "\n" and collect the slices into a vector
  }
}

// Assumes there are no comments in the bulk of the text.
let range_separator = lines.len().min(100); // Find the minimum of 100 and the number of lines
lines = lines[..range_separator].into_iter().filter(|line| { // Iterate over the first range_separator lines and filter out any line that
  !line.trim_start().starts_with("#") // starts with "#" after trimming leading whitespace
}).cloned().collect::<Vec<_>>() // clone the remaining slices and collect them into a vector
  + &lines[range_separator..]; // append the rest of the lines

fn assert_new_line(string: &str) { // Define a function to check if a string is empty
  if string != "" { // If the string is not empty
    start_error("", string); // Call the start_error function with an empty string and the given string
  }
}

let checkpoint2 = Instant::now(); // Store the current time
log_checkpoint(message="Preprocessed text in", start=checkpoint1, end=checkpoint2); // Print how much time it took to preprocess the text

assert_expected_prefix("specification:", lines[0]); // Check that the first line starts with "specification:"
remove_expected_prefix("  - https://github.com", &mut lines[1]); // Remove "  - https://github.com" from the second line
assert_new_line(lines[2]); // Check that the third line is empty

assert_expected_prefix("header:", lines[3]); // Check that the fourth line starts with "header:"
remove_expected_prefix("  frame time in femtoseconds: ", &mut lines[4]); // Remove "  frame time in femtoseconds: " from the fifth line
let frame_time_in_fs = lines[4].parse::<f64>().unwrap(); // Parse the fifth line as a floating-point number
remove_expected_prefix("  spatial resolution in approximate picometers: ", &mut lines[5]); // Remove "  spatial resolution in approximate picometers: " from the sixth line
let resolution_in_approx_pm = lines[5].parse::<f64>().unwrap(); // Parse the sixth line as a floating-point number

remove_expected_prefix("  uses checkpoints: ", &mut lines[6]); // Remove "  uses checkpoints: " from the seventh line
match lines[6] { // Match on the seventh line
  "false" => {}, // If it is "false", do nothing
  "true" => panic!("Checkpoints not recognized yet."), // If it is "true", panic with an error message
  _ => panic!("Error parsing {}", lines[6]), // Otherwise, panic with another error message
}

remove_expected_prefix("  frame count: ", &mut lines[7]); // Remove "  frame count: " from the eighth line
let frame_count = lines[7].parse::<usize>().unwrap(); // Parse the eighth line as an unsigned integer
remove_expected_prefix("  frame cluster size: ", &mut lines[8]); // Remove "  frame cluster size: " from the ninth line
let cluster_size = lines[8].parse::<usize>().unwrap(); // Parse the ninth line as an unsigned integer
assert_new_line(lines[9]); // Check that the tenth line is empty

assert_expected_prefix("metadata:", lines[10]); // Check that the eleventh line starts with "metadata:"
assert_new_line(lines[11]); // Check that the twelfth line is empty

// MARK: - Frames

struct Atom { // Define a struct to represent an atom
  x: f32, // A field for x coordinate as a floating-point number
  y: f32, // A field for y coordinate as a floating-point number
  z: f32, // A field for z coordinate as a floating-point number
  element: u8, // A field for element as an unsigned byte
  flags: u8, // A field for flags as an unsigned byte
  
  origin: fn(&Self) -> [f32;3], // A field for origin as a function that takes a reference to self and returns an array of three floating-point numbers
}
impl Atom {
// Implement some methods for Atom struct
fn new(x:f32,y:f32,z:f32,element:u8,flags:u8)->Self{
// Define a constructor method that takes five parameters and returns an instance of Atom
Self{
    // Initialize the fields with the parameters
    x,
    y,
    z,
    element,
    flags,
    // Define a closure for the origin field that returns an array of x, y, and z coordinates
    origin: |self| [self.x, self.y, self.z],
  }
}
}

let mut clusters: Vec<Vec<Vec<Atom>>> = vec![vec![]; cluster_ranges.len()]; // Create a vector of vectors of vectors of atoms with the same length as the cluster ranges vector

// Data for multithreading.
let num_cores = num_cpus::get(); // Get the number of available CPUs
let num_cores = num_cores.min(cluster_ranges.len()); // Find the minimum of the number of CPUs and the number of cluster ranges
let finished_cluster_count = Arc::new(Mutex::new(num_cores)); // Create an atomic variable to store the number of finished clusters

// Use rayon to parallelize the iteration over the cluster ranges
cluster_ranges.into_par_iter().enumerate().for_each(|(i, range)| {
  let (range, cluster_id) = { // Create a scope to borrow the atomic variable
    let mut finished_cluster_count = finished_cluster_count.lock().unwrap(); // Lock the atomic variable and get a mutable reference
    if i > num_cores { // If the index is greater than the number of cores
      if *finished_cluster_count >= cluster_ranges.len() { // If all clusters are finished
        return; // Return early from the closure
      }
      let range = cluster_ranges[*finished_cluster_count]; // Get the range from the cluster ranges vector at the finished cluster count index
      let cluster_id = *finished_cluster_count; // Get the cluster ID from the finished cluster count index
      *finished_cluster_count += 1; // Increment the finished cluster count by one
      (range, cluster_id) // Return a tuple of range and cluster ID
    } else {
      (range, i) // Return a tuple of range and index
    }
  };
  
  let mut cluster_lines: Vec<&str> = lines[range.start..range.end].to_vec(); // Create a vector of string slices from the lines vector at the given range
  let frame_start = cluster_id * cluster_size; // Calculate the frame start by multiplying the cluster ID and the cluster size
  remove_expected_prefix("  frame start: ", &mut cluster_lines[1]); // Remove "  frame start: " from the second line in the vector
  remove_expected_prefix(&frame_start.to_string(), &mut cluster_lines[1]); // Remove the frame start value from the second line in the vector
  remove_expected_prefix("  frame end: ", &mut cluster_lines[2]); // Remove "  frame end: " from the third line in the vector
  let frame_end: usize = extract_excluding(" ", &mut cluster_lines[2]).parse().unwrap(); // Extract and parse the frame end value from the third line in the vector
  remove_expected_prefix("  metadata:", &mut cluster_lines[3]); // Remove "  metadata:" from the fourth line in the vector
  
  // Assume there is no per-frame metadata.
  remove_expected_prefix("  atoms:", &mut cluster_lines[4]); // Remove "  atoms:" from the fifth line in the vector
  
  let num_atoms_lines = cluster_lines.len() - 5 - 3 - 2; // Calculate the number of lines for atoms by subtracting some constants from the length of the vector
  assert!(num_atoms_lines % 3 == 0, "Unexpected number of lines."); // Assert that the number of lines for atoms is divisible by three or panic with an error message
  let num_atoms = num_atoms_lines / 3; // Calculate the number of atoms by dividing by three
  
  let mut temp_pointers: Vec<Vec<u8>> = vec![vec![0u8;2];2]; // Create a vector of vectors of bytes with four elements and each element has two bytes
  
  let mut line_id = 5; // Initialize a variable to store the line ID
  let mut all_axes_coords: Vec<Vec<Vec<f32>>> = Vec::new(); // Create an empty vector to store all axes coordinates
  for coordinate in ["x", "y", "z"].iter() { // Iterate over an array of coordinate names
    remove_expected_prefix(&format!("    {}", coordinate), &mut cluster_lines[line_id]); // Remove "    x/y/z" from the corresponding line in the vector
    remove_expected_prefix(" coordinates:", &mut cluster_lines[line_id]); // Remove " coordinates:" from the same line in the vector
    line_id += 1; // Increment the line ID by one
    
    let mut all_atoms_coords: Vec<Vec<f32>> = Vec::new(); // Create an empty vector to store all atoms coordinates for the current axis

#[cfg(feature = "release")]
{
  let num_vectors = num_atoms / 2; // Calculate the number of vectors by dividing the number of atoms by two
}
#[cfg(not(feature = "release"))]
{
  let num_vectors = 0; // Set the number of vectors to zero
}
for vector_id in 0..num_vectors { // Iterate over each vector ID from zero to num_vectors
  // Copy the strings' raw data to a custom memory region.
  let mut string_max_indices: [i32;2] = [0;2]; // Create an array of two 32-bit integers and initialize them to zero
  for lane in 0..2 { // Iterate over each lane from zero to one
    fn round_up_to_power_of_2(input: usize) -> usize { // Define a function to round up an integer to the next power of two
      1 << (mem::size_of::<usize>() * 8 - input.saturating_sub(1).leading_zeros() as usize)
    }
    let raw_count = cluster_lines[line_id + lane].len(); // Get the length of the string at the corresponding line ID and lane
    string_max_indices[lane] = (raw_count - 1) as i32; // Store the adjusted length as a 32-bit integer in the array
    
    let rounded_count = round_up_to_power_of_2(raw_count); // Round up the length to the next power of two
    if rounded_count > temp_pointers[lane].len() { // If the rounded length is greater than the capacity of the temporary pointer at the lane
      temp_pointers[lane].deallocate(); // Deallocate the temporary pointer at the lane
      temp_pointers[lane] = Vec::with_capacity(rounded_count); // Create a new vector of bytes with the rounded capacity and assign it to the temporary pointer at the lane
    }
    cluster_lines[line_id + lane].as_bytes().iter().for_each(|&byte| { // Iterate over each byte in the string slice at the corresponding line ID and lane
      temp_pointers[lane].push(byte); // Push the byte to the vector at the temporary pointer at the lane
    });
  }
  line_id += 2; // Increment the line ID by two
  
  let mut cursors: [i32;2] = [0;2]; // Create an array of two 32-bit integers and initialize them to zero
  let lane_ids = [0,1]; // Create an array of two integers with values zero and one
  let mut atom_ids: [i32;2] = [(vector_id * 2) as i32, (vector_id * 2 + 1) as i32]; // Create an array of two 32-bit integers with values calculated from the vector ID
  #[inline(always)]
  fn fetch(temp_pointers: &Vec<Vec<u8>>, cursors: &[i32;2], string_max_indices: &[i32;2]) -> [i32;2] { // Define a function to fetch two bytes from the temporary pointers using the cursors and string max indices
    let mut output: [i32;2] = [0;2]; // Create an output array of two 32-bit integers and initialize them to zero
    let mut bounded_cursors = cursors.clone(); // Create a copy of the cursors array
    for lane in 0..2 { // Iterate over each lane from zero to one
      if bounded_cursors[lane] > string_max_indices[lane] { // If the cursor at the lane is greater than the string max index at the lane
        bounded_cursors[lane] = string_max_indices[lane]; // Set the bounded cursor at the lane to be equal to the string max index at the lane
      }
      output[lane] = temp_pointers[lane][bounded_cursors[lane] as usize] as i32; // Get the byte from the temporary pointer at the lane using the bounded cursor at the lane and cast it to a 32-bit integer and store it in the output array at the lane
      if cursors[lane] > string_max_indices[lane] { // If the cursor at the lane is greater than the string max index at the lane
        output[lane] = 32; // Set the output at the lane to be equal to 32 (space character)
      }
    }
    output // Return the output array
  }
  
  let mut remainders = atom_ids.clone(); // Create a copy of the atom IDs array and assign it to a variable called remainders
  while remainders.iter().any(|&x| x > 0) { // While any element in the remainders array is greater than zero
    let mut active_mask: [i32;2] = [0;2]; // Create an array of two 32-bit integers and initialize them to zero
    for lane in 0..2 { // Iterate over each lane from zero to one
      if remainders[lane] > 0 { // If the remainder at the lane is greater than zero
        active_mask[lane] = 1; // Set the active mask at the lane to be equal to one
      }
    }
    cursors.iter_mut().zip(active_mask.iter()).for_each(|(x,y)| *x += y); // Add the active mask to the cursors element-wise and store the result in the cursors array
    remainders.iter_mut().for_each(|x| *x /= 10); // Divide the remainders by 10 element-wise and store the result in the remainders array
  }
  {
    let zero_mask: [bool;2] = atom_ids.iter().map(|&x| x == 0).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two booleans with values indicating whether the atom IDs are equal to zero
    for lane in 0..2 { // Iterate over each lane from zero to one
      if zero_mask[lane] { // If the zero mask at the lane is true
        cursors[lane] += 1; // Increment the cursor at the lane by one
      }
    }
  }
  cursors.iter_mut().for_each(|x| *x += ":".len() as i32); // Add the length of ":" to the cursors element-wise and store the result in the cursors array
  
  let mut arrays: Vec<Vec<f32>> = vec![vec![];2]; // Create a vector of two vectors of floating-point numbers and initialize them with empty vectors
  for lane in 0..2 { // Iterate over each lane from zero to one
    arrays[lane].reserve(frame_end - frame_start + 1); // Reserve enough capacity for the vector at the lane to store all frames
  }
  for frame_id in 0..(frame_end - frame_start + 1) { // Iterate over each frame ID from zero to frame_end - frame_start + 1
    let characters = fetch(&temp_pointers, &cursors, &string_max_indices); // Call the fetch function with the temporary pointers, cursors, and string max indices and get an array of two characters
    assert!(characters.iter().all(|&x| x == 32), "One of the numbers did not begin with a space."); // Assert that all characters are equal to 32 (space character) or panic with an error message
    cursors.iter_mut().for_each(|x| *x += 1); // Increment the cursors by one element-wise and store the result in the cursors array
    
    let mut active_mask: [i32;2] = [1;2]; // Create an array of two 32-bit integers and initialize them to one
    let mut signs: [i32;2] = [1;2]; // Create an array of two 32-bit integers and initialize them to one
    let mut cumulative_sums: [i32;2] = [0;2]; // Create an array of two 32-bit integers and initialize them to zero
    while active_mask.iter().any(|&x| x > 0) { // While any element in the active mask array is greater than zero
      let characters = fetch(&temp_pointers, &cursors, &string_max_indices); // Call the fetch function with the temporary pointers, cursors, and string max indices and get an array of two characters
      
      let mut space_mask: [bool;2] = characters.iter().map(|&x| x == 32).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two booleans with values indicating whether the characters are equal to 32 (space character)
      for lane in 0..2 { // Iterate over each lane from zero to one
        if space_mask[lane] && active_mask[lane] > 0 { // If the space mask at the lane is true and the active mask at the lane is greater than zero
          active_mask[lane] = 0; // Set the active mask at the lane to be equal to zero
        }
      }
      
      let mut cursor_mask: [bool;2] = characters.iter().map(|&x| x != 32).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two booleans with values indicating whether the characters are not equal to 32 (space character)
      for lane in 0..2 { // Iterate over each
        if cursor_mask[lane] && active_mask[lane] > 0 { // If the cursor mask at the lane is true and the active mask at the lane is greater than zero
          cursors[lane] += 1; // Increment the cursor at the lane by one
        }
      }
      
      let mut minus_mask: [bool;2] = characters.iter().map(|&x| x == 0o55).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two booleans with values indicating whether the characters are equal to 0o55 (minus character)
      for lane in 0..2 { // Iterate over each lane from zero to one
        if minus_mask[lane] && active_mask[lane] > 0 { // If the minus mask at the lane is true and the active mask at the lane is greater than zero
          signs[lane] = -1; // Set the sign at the lane to be equal to -1
        }
      }
      
      let digits: [i32;2] = characters.iter().map(|&x| x as i32 - 48).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two 32-bit integers with values calculated by subtracting 48 from the characters
      let mut digit_mask: [bool;2] = digits.iter().zip(&[0,9]).map(|(&x,&y)| x >= y && x <= y).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two booleans with values indicating whether the digits are between 0 and 9
      for lane in 0..2 { // Iterate over each lane from zero to one
        if digit_mask[lane] && active_mask[lane] > 0 { // If the digit mask at the lane is true and the active mask at the lane is greater than zero
          cumulative_sums[lane] = cumulative_sums[lane] * 10 + digits[lane]; // Update the cumulative sum at the lane by multiplying by 10 and adding the digit at the lane
        }
      }
    }
    
    let mut floats: [f32;2] = cumulative_sums.iter().map(|&x| x as f32).collect::<Vec<_>>().try_into().unwrap(); // Create an array of two floating-point numbers with values casted from the cumulative sums
    let multiplier = resolution_in_approx_pm / 1024.0; // Calculate a multiplier by dividing the resolution in approximate picometers by 1024.0
    floats.iter_mut().for_each(|x| *x *= multiplier); // Multiply the floats by the multiplier element-wise and store the result in the floats array
    for lane in 0..2 { // Iterate over each lane from zero to one
      arrays[lane].push(floats[lane]); // Push the float at the lane to the vector at the lane
    }
  }
  
  for lane in 0..2 { // Iterate over each lane from zero to one
    all_atoms_coords.push(arrays[lane].clone()); // Push a clone of the vector at the lane to the all atoms coordinates vector
  }
}

for atom_id in (num_vectors * 2)..num_atoms { // Iterate over each atom ID from num_vectors * 2 to num_atoms
  cluster_lines[line_id].trim_start(); // Trim leading whitespace from the line at line ID
  
  var atom_ids: [Int32;1] = [(atom_id + 1) as i32]; // Create an array of one 32-bit integer with value calculated from atom ID
  var remainders = atom_ids.clone(); // Create a copy of atom IDs array and assign it to a variable called remainders
  while remainders[0] > 0 { // While the element in remainders array is greater than zero
    cursors[0] += 1; // Increment cursor by one
    remainders[0] /= 10; // Divide remainder by ten and store result in remainder
  }
  
}

#[cfg(feature = "release")]
{
  let do_loop = num_vectors * 2 < num_atoms; // Calculate a boolean value by comparing the product of num_vectors and two with num_atoms
  let mut current_atom_id = num_vectors * 2; // Initialize a mutable variable to store the current atom ID as the product of num_vectors and two
}
#[cfg(not(feature = "release"))]
{
  let do_loop = true; // Set the do loop value to true
  let mut current_atom_id = 0; // Initialize a mutable variable to store the current atom ID as zero
}
while do_loop { // Start a while loop with the do loop condition
  assert_expected_prefix("    ", cluster_lines[line_id]); // Check that the line at line ID starts with "    "
  if !cluster_lines[line_id].starts_with("     ") { // If the line at line ID does not start with "     "
    break; // Break out of the loop
  }
  line_id += 1; // Increment the line ID by one
  
  remove_expected_prefix(
    &format!("      - {}:", current_atom_id), &mut cluster_lines[line_id]); // Remove "      - current_atom_id:" from the line at line ID
  current_atom_id += 1; // Increment the current atom ID by one
  
  let mut cumulative_sum: i32 = 0; // Initialize a mutable variable to store the cumulative sum as zero
  let multiplier = resolution_in_approx_pm / 1024.0; // Calculate a multiplier by dividing the resolution in approximate picometers by 1024.0
  let mut coords: Vec<f32> = Vec::new(); // Create an empty vector to store the coordinates as floating-point numbers
  let mut number_sign: i32 = 1; // Initialize a mutable variable to store the number sign as one
  let mut number_accumulated: i32 = 0; // Initialize a mutable variable to store the number accumulated as zero
  #[inline(always)]
  fn append_latest_number(
    number_accumulated: &mut i32,
    number_sign: &mut i32,
    cumulative_sum: &mut i32,
    multiplier: f32,
    coords: &mut Vec<f32>) { // Define a function to append the latest number to the coordinates vector
    *number_accumulated *= *number_sign; // Multiply the number accumulated by the number sign and store the result in the number accumulated
    let integer = *number_accumulated; // Store the number accumulated as an integer
    *number_sign = 1; // Reset the number sign to one
    *number_accumulated = 0; // Reset the number accumulated to zero
    
    *cumulative_sum += integer; // Add the integer to the cumulative sum and store the result in the cumulative sum
    let float = integer as f32 * multiplier; // Multiply the integer by the multiplier and cast it to a floating-point number and store it as a float
    coords.push(float); // Push the float to the coordinates vector
  }
  
  // Now, we need to vectorize the code across the number of atoms.
  remove_expected_prefix(" ", &mut cluster_lines[line_id]); // Remove " " from the line at line ID
  cluster_lines[line_id].as_bytes().iter().for_each(|&byte| { // Iterate over each byte in the string slice at line ID
    match byte { // Match on the byte value
      b' ' => append_latest_number( // If it is a space character, call the append latest number function with
        &mut number_accumulated,
        &mut number_sign,
        &mut cumulative_sum,
        multiplier,
        &mut coords),
      b'-' => number_sign = -1, // If it is a minus character, set the number sign to -1
      _ => { // Otherwise,
        let digit = byte as i32 - b'0' as i32; // Subtract b'0' from byte and cast them to 32-bit integers and store it as a digit
        number_accumulated = number_accumulated * 10 + digit; // Multiply the number accumulated by 10 and add the digit and store it in the number accumulated
      }
    }
  });
  append_latest_number( // Call the append latest number function with
    &mut number_accumulated,
    &mut number_sign,
    &mut cumulative_sum,
    multiplier,
    &mut coords); // the same parameters as before
  
  all_atoms_coords.push(coords); // Push the coordinates vector to the all atoms coordinates vector
}
all_axes_coords.push(all_atoms_coords); // Push the all atoms coordinates vector to the all axes coordinates vector
}

let mut tail: Vec<Vec<u8>> = Vec::new(); // Create an empty vector to store the tail data as vectors of bytes
for label in ["elements", "flags"].iter() { // Iterate over an array of label names
  remove_expected_prefix(&format!("    {}:", label), &mut cluster_lines[line_id]); // Remove "    label:" from the line at line ID
  line_id += 1; // Increment the line ID by one
  
  let mut array: Vec<u8> = Vec::new(); // Create an empty vector to store the data as bytes
  tail.push(array.clone()); // Push a clone of the vector to the tail vector
  
  for atom_id in 0..num_atoms { // Iterate over each atom ID from zero to num_atoms
    remove_expected_prefix(" ", &mut cluster_lines[line_id]); // Remove " " from the line at line ID
    let value = cluster_lines[line_id].parse::<u8>().unwrap(); // Parse the value from the line at line ID as an unsigned byte
    array.push(value); // Push the value to the array vector
  }
}

let mut cluster: Vec<Vec<Atom>> = Vec::new(); // Create an empty vector to store the cluster data as vectors of atoms
for frame_id in 0..(frame_end - frame_start + 1) { // Iterate over each frame ID from zero to frame_end - frame_start + 1
  let mut array: Vec<Atom> = Vec::new(); // Create an empty vector to store the frame data as atoms
  array.reserve(num_atoms); // Reserve enough capacity for the vector to store all atoms
  
  for atom_id in 0..num_atoms { // Iterate over each atom ID from zero to num_atoms
    let x = all_axes_coords[0][atom_id][frame_id]; // Get the x coordinate from the all axes coordinates vector at index zero, atom ID, and frame ID
    let y = all_axes_coords[1][atom_id][frame_id]; // Get the y coordinate from the all axes coordinates vector at index one, atom ID, and frame ID
    let z = all_axes_coords[2][atom_id][frame_id]; // Get the z coordinate from the all axes coordinates vector at index two, atom ID, and frame ID
    let element = tail[0][atom_id]; // Get the element from the tail vector at index zero and atom ID
    let flags = tail[1][atom_id]; // Get the flags from the tail vector at index one and atom ID
    
    let atom = Atom::new(x, y, z, element, flags); // Create a new instance of Atom struct with the values
    array.push(atom); // Push the atom to the array vector
  }
  cluster.push(array); // Push the array vector to the cluster vector
}

queue.lock().unwrap()[cluster_id] = cluster; // Lock the queue and assign the cluster vector to it at cluster ID index
});
let frames: Vec<Vec<Atom>> = clusters.into_iter().flatten().collect(); // Flatten and collect the clusters into a vector of vectors of atoms

let checkpoint4 = Instant::now(); // Store the current time
log_checkpoint(message="Parsed clusters in", start=checkpoint3, end=checkpoint4); // Print how much time it took to parse clusters
log_checkpoint(message="Total decoding time", start=checkpoint0, end=checkpoint4); // Print how much time it took to decode

let random_frame_ids: Vec<usize> = (0..10).map(|_| rand::thread_rng().gen_range(0..frames.len())).sorted().collect(); // Create a vector of ten random frame IDs sorted in ascending order

// Track the same few atoms across all frames.
let random_atom_ids: Vec<usize> = (0..4).map(|_| rand::thread_rng().gen_range(0..frames[0].len())).sorted().collect(); // Create a vector of four random atom IDs sorted in ascending order

for frame_id in random_frame_ids { // Iterate over each frame ID in random frame IDs
  assert_eq!(frames[frame_id].len(), frames[0].len()); // Assert that the number of atoms in each frame is equal or panic with an error message
  let time_stamp_in_ps = frame_id as f64 * frame_time_in_fs / 1e3; // Calculate the time stamp in picoseconds by multiplying the frame ID and the frame time in femtoseconds and dividing by 1e3
  println!(); // Print a new line
  println!("Frame {}", frame_id); // Print the frame ID
  println!("- timestamp: {:.3} ps", time_stamp_in_ps); // Print the time stamp with three decimal places
  
  for atom_id in random_atom_ids { // Iterate over each atom ID in random atom IDs
    let atom = frames[frame_id][atom_id]; // Get the atom from the frames vector at frame ID and atom ID indices
    println!(" - atom {}: {:.3} {:.3} {:.3} {} {}", atom_id, atom.x, atom.y, atom.z, atom.element, atom.flags); // Print the atom ID and the atom fields with three decimal places for coordinates
  }
}

println!(); // Print a new line
println!("{}", log); // Print the log
