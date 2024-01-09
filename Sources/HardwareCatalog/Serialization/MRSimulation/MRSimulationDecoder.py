# MARK: - Utilities

import sys
import time
import math
import threading

def start_error(start, sequence, line, function):
  # Raise a fatal error with a message that the start is not the start of the sequence
  sys.exit(f"'{start}' is not the start of '{sequence}'.")

def assert_expected_prefix(prefix, text):
  # Check if the text starts with the prefix, otherwise call the start_error function
  if not text.startswith(prefix):
    start_error(prefix, text, sys._getframe().f_lineno, sys._getframe().f_code.co_name)

def remove_expected_prefix(prefix, text):
  # Remove the prefix from the start of the text and return the modified text
  assert_expected_prefix(prefix, text)
  return text[len(prefix):]

def remove_including(prefix, text):
  # Remove all occurrences of the prefix from the start of the text and return the modified text
  while text.startswith(prefix):
    text = text[len(prefix):]
  return text

def remove_excluding(prefix, text):
  # Remove everything from the start of the text until it reaches the prefix and return the modified text
  while not text.startswith(prefix):
    text = text[len(prefix):]
    if len(text) == 0:
      break
  return text

def extract_excluding(prefix, text):
  # Return a new string that contains everything from the start of the text until it reaches the prefix and remove it from the original text
  output = ""
  while not text.startswith(prefix):
    output += text[:len(prefix)]
    text = text[len(prefix):]
    if len(text) == 0:
      break
  return output, text

def large_integer_repr(number):
  # Return a string that represents a large integer in a human-readable format
  if number < 1000:
    return str(number)
  elif number < 1000000:
    radix = 1000
    return f"{number // radix}.{number % radix // 100} thousand"
  elif number < 1000000000:
    radix = 1000000
    return f"{number // radix}.{number % radix // (radix // 10)} million"
  elif number < 1000000000000:
    radix = 1000000000
    return f"{number // radix}.{number % radix // (radix // 10)} billion"
  else:
    radix = 1000000000000
    return f"{number // radix}.{number % radix // (radix // 10)} trillion"

def latency_repr(number):
  # Return a string that represents a latency in terms of microseconds, milliseconds, seconds, minutes or hours
  number = int(round(number * 1e6)) # microseconds
  if number < 1000:
    return f"{number} µs"
  elif number < 1000000:
    radix = 1000
    return f"{number // radix}.{number % radix // (radix // 10)} ms"
  elif number < 60 * 1000000:
    radix = 1000000
    return f"{number // radix}.{number % radix // (radix // 10)} s"
  elif number < 3600 * 1000000:
    radix = 60 * 1000000
    return f"{number // radix}.{number % radix // (radix // 10)} min"
  else:
    radix = 3600 * 1000000
    return f"{number // radix}.{number % radix // (radix //10)} hr"

log = ""
def log_checkpoint(message, start, end):
   global log

   # Print a log message that shows how much time elapsed between the start and end dates and append it to the log variable
   seconds = end - start
   str = f"{message}: \u001b[0;33m{latency_repr(seconds)}\u001b[0m"
   log += str + "\n"
   print(str)

# MARK: - Header

import sys
import time
import os

checkpoint0 = time.time() # Store the current time
file_path = sys.argv[1] # Get the file path from the command line arguments
try:
  with open(file_path, "r", encoding="utf-8") as f:
    contents = f.read() # Read the contents of the file as a string
except FileNotFoundError:
  current_dir = os.getcwd() # Get the current directory
  sys.exit(f"File not found at path: {current_dir}/{file_path}") # Exit with an error message

contents_buffer = bytearray(contents, "utf-8") # Create a buffer of bytes from the string

checkpoint1 = time.time() # Store the current time
log_checkpoint(message="Loaded file in", start=checkpoint0, end=checkpoint1) # Print how much time it took to load the file

if "\r" in contents[:100]:
  # Remove \r on Windows.
  lines = contents.split("\r\n")
else:
  lines = contents.split("\n")

# Assumes there are no comments in the bulk of the text.
range_separator = min(100, len(lines))
lines = [line for line in lines[:range_separator] if not line.lstrip().startswith("#")] + lines[range_separator:]

def assert_new_line(string):
  if string != "":
    start_error("", string)

checkpoint2 = time.time() # Store the current time
log_checkpoint(message="Preprocessed text in", start=checkpoint1, end=checkpoint2) # Print how much time it took to preprocess the text

assert_expected_prefix("specification:", lines[0])
assert_expected_prefix("  - https://github.com", lines[1])
assert_new_line(lines[2])

assert_expected_prefix("header:", lines[3])
lines[4] = remove_expected_prefix("  frame time in femtoseconds: ", lines[4])
frame_time_in_fs = float(lines[4])
lines[5] = remove_expected_prefix("  spatial resolution in approximate picometers: ", lines[5])
resolution_in_approx_pm = float(lines[5])

lines[6] = remove_expected_prefix("  uses checkpoints: ", lines[6])
if lines[6] == "false":
  pass
elif lines[6] == "true":
  sys.exit("Checkpoints not recognized yet.")
else:
  sys.exit(f"Error parsing {lines[6]}.")

lines[7] = remove_expected_prefix("  frame count: ", lines[7])
frame_count = int(lines[7])
lines[8] = remove_expected_prefix("  frame cluster size: ", lines[8])
cluster_size = int(lines[8])
assert_new_line(lines[9])

assert_expected_prefix("metadata:", lines[10])
assert_new_line(lines[11])

cluster_ranges = []
cluster_start = None
for i in range(12, len(lines)):
  if cluster_start is None:
    if len(lines[i]) == 0:
      # Allow multiple newlines, especially at the end of the file.
      continue
    
    lines[i] = remove_including("frame cluster ", lines[i])
    cluster_id, lines[i] = extract_excluding(":", lines[i])
    cluster_id = int(cluster_id)
    expected = len(cluster_ranges)
    if cluster_id != expected:
      sys.exit(f"Cluster ID {cluster_id} does not match expected {expected}.")
    cluster_start = i
  else:
    if len(lines[i]) == 0:
      assert cluster_start is not None
      cluster_ranges.append(range(cluster_start, i))
      cluster_start = None

checkpoint3 = time.time() # Store the current time
log_checkpoint(message="Parsed header in", start=checkpoint2, end=checkpoint3) # Print how much time it took to parse the header

# MARK: - Frames

class Atom:
  def __init__(self, x, y, z, element, flags):
    self.x = x
    self.y = y
    self.z = z
    self.element = element
    self.flags = flags
  
  @property
  def origin(self):
    return (self.x, self.y, self.z)

clusters = [[] for _ in range(len(cluster_ranges))]

# Data for multithreading.
num_cores = 1
num_cores = min(num_cores, len(cluster_ranges))
finished_cluster_count = 0

for z in range(1):
  while True:
    if finished_cluster_count >= len(cluster_ranges):
      break
    cluster_range = cluster_ranges[finished_cluster_count]
    cluster_id = finished_cluster_count
    finished_cluster_count += 1
    
    cluster_lines = lines[cluster_range[0]:(cluster_range[-1]+1)]
    frame_start = cluster_id * cluster_size
    cluster_lines[1] = remove_expected_prefix("  frame start: ", cluster_lines[1])
    cluster_lines[1] = remove_expected_prefix(str(frame_start), cluster_lines[1])
    cluster_lines[2] = remove_expected_prefix("  frame end: ", cluster_lines[2])
    frame_end, cluster_lines[2] = extract_excluding(" ", cluster_lines[2])
    frame_end = int(frame_end)
    cluster_lines[3] = remove_expected_prefix("  metadata:", cluster_lines[3])
    
    # Assume there is no per-frame metadata.
    cluster_lines[4] = remove_expected_prefix("  atoms:", cluster_lines[4])
    
    num_atoms_lines = len(cluster_lines) - 5 - 3 - 2
    assert num_atoms_lines % 3 == 0, "Unexpected number of lines."
    num_atoms = num_atoms_lines // 3
    
    temp_pointers = [bytearray(2) for _ in range(2)]
    
    line_id = 5
    all_axes_coords = []
    for coordinate in ["x", "y", "z"]:
      cluster_lines[line_id] = remove_expected_prefix(f"    {coordinate}", cluster_lines[line_id])
      cluster_lines[line_id] = remove_expected_prefix(" coordinates:", cluster_lines[line_id])
      line_id += 1
      
      all_atoms_coords = []
      current_atom_id = 0
      while True:
        assert_expected_prefix("    ", cluster_lines[line_id])
        if not cluster_lines[line_id].startswith("     "):
          break
        cluster_lines[line_id] = remove_expected_prefix(f"      - {current_atom_id}:", cluster_lines[line_id])
        current_atom_id += 1
        
        cumulative_sum = 0
        multiplier = resolution_in_approx_pm / 1024
        coords = []
        number_sign = 1
        number_accumulated = 0
        
        def append_latest_number():
          global number_sign, number_accumulated, cumulative_sum, coords
          number_accumulated *= number_sign
          integer = number_accumulated
          number_sign = 1
          number_accumulated = 0
          
          cumulative_sum += integer
          float_ = float(integer) * multiplier
          coords.append(float_)
        
        # Now, we need to vectorize the code across the number of atoms.
        cluster_lines[line_id] = remove_expected_prefix(" ", cluster_lines[line_id])
        buffer_ = bytes(cluster_lines[line_id], "utf-8")
        for char_id in range(len(buffer_)):
          char_ = buffer_[char_id]
          if char_ == 32:
            append_latest_number()
          elif char_ == ord("-"):
            number_sign = -1
          else:
            digit_ = int(char_) - ord("0")
            number_accumulated = number_accumulated * 10 + digit_
        append_latest_number()
        
        all_atoms_coords.append(coords)
        line_id += 1
      
      all_axes_coords.append(all_atoms_coords)
    
    tail = []
    for label in ["elements", "flags"]:
      cluster_lines[line_id] = remove_expected_prefix(f"    {label}:", cluster_lines[line_id])
      
      array = []
      for atom_id in range(num_atoms):
        cluster_lines[line_id] = remove_expected_prefix(" ", cluster_lines[line_id])
        value, cluster_lines[line_id] = extract_excluding(" ", cluster_lines[line_id])
        array.append(int(value))
      
      tail.append(array)
      line_id += 1
    
    cluster = []
    for frame_id in range(0, frame_end + 1 - frame_start):
      array = []
      
      for atom_id in range(num_atoms):
        x = all_axes_coords[0][atom_id][frame_id]
        y = all_axes_coords[1][atom_id][frame_id]
        z = all_axes_coords[2][atom_id][frame_id]
        element = tail[0][atom_id]
        flags = tail[1][atom_id]
        
        atom = Atom(x, y, z, element, flags)
        array.append(atom)
      cluster.append(array)
    
    clusters[cluster_id] = cluster

frames = [atom for cluster in clusters for atom in cluster]

checkpoint4 = time.time() # Store the current time
log_checkpoint(message="Parsed clusters in", start=checkpoint3, end=checkpoint4) # Print how much time it took to parse the clusters
log_checkpoint(message="Total decoding time", start=checkpoint0, end=checkpoint4) # Print how much time it took to decode the entire file

import random
from random import sample

random_frame_ids = sorted(random.sample(range(len(frames)), 10))

# Track the same few atoms across all frames.
random_atom_ids = sorted(random.sample(range(len(frames[0])), 4))

for frame_id in random_frame_ids:
  assert len(frames[frame_id]) == len(frames[0])
  time_stamp_in_ps = float(frame_id) * frame_time_in_fs / 1e3
  print()
  print(f"Frame {frame_id}")
  print(f"- timestamp: {time_stamp_in_ps:.3f} ps")
  
  for atom_id in random_atom_ids:
    atom = frames[frame_id][atom_id]
    print(f" - atom {atom_id}: {atom.x:.3f} {atom.y:.3f} {atom.z:.3f} {atom.element} {atom.flags}")

print()
print(log)
