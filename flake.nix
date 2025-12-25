{
  description = "Advanced file splitter with verification, manifest support, and bit-perfect integrity checking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;
        
        version = "1.0.0";
        pname = "afs";
        
      in {
        packages = {
          default = pkgs.stdenvNoCC.mkDerivation {
            inherit pname version;

            dontUnpack = true;
            dontBuild = true;

            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ python ];

            installPhase = ''
              mkdir -p $out/bin
              cat > $out/bin/${pname} <<'EOF'
#!/usr/bin/env python3
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright © 2025 DeMoD LLC
# All rights reserved.

import os
import hashlib
import argparse
import shutil
import tempfile
import json
import sys
import re
from pathlib import Path
from typing import List, Tuple, Optional

__version__ = "${version}"

DEFAULT_PARTS = 24
DEFAULT_PART_SIZE_MB = 25
MAX_PART_SIZE_BYTES = DEFAULT_PART_SIZE_MB * 1024 * 1024

class FileSplitter:
    """Enhanced file splitter with verification and manifest support."""
    
    def __init__(self, hash_algorithm: str = 'sha256', quiet: bool = False):
        self.hash_algorithm = hash_algorithm
        self.chunk_size = 4 * 1024 * 1024  # 4MB chunks for I/O
        self.quiet = quiet
    
    def log(self, message: str) -> None:
        """Print message unless in quiet mode."""
        if not self.quiet:
            print(message)
    
    def compute_hash(self, file_path: str) -> str:
        """Compute hash of a file using chunked reading."""
        hash_func = hashlib.new(self.hash_algorithm)
        try:
            with open(file_path, 'rb') as f:
                while chunk := f.read(self.chunk_size):
                    hash_func.update(chunk)
            return hash_func.hexdigest()
        except IOError as e:
            raise ValueError(f"Error reading file {file_path}: {e}")
    
    def split_file(self, input_file: str, output_dir: str, 
                   num_parts: Optional[int] = None,
                   max_part_size: Optional[int] = None) -> List[Tuple[str, str]]:
        """Split file into parts with flexible sizing options."""
        file_size = os.path.getsize(input_file)
        if file_size == 0:
            raise ValueError("Input file is empty")
        
        if num_parts is not None:
            if num_parts < 1:
                raise ValueError("Number of parts must be at least 1")
            chunk_size = file_size // num_parts
            remainder = file_size % num_parts
            actual_parts = num_parts
        elif max_part_size is not None:
            if max_part_size < 1:
                raise ValueError("Max part size must be at least 1 byte")
            actual_parts = (file_size + max_part_size - 1) // max_part_size
            chunk_size = file_size // actual_parts
            remainder = file_size % actual_parts
        else:
            actual_parts = min(DEFAULT_PARTS, file_size)
            chunk_size = file_size // actual_parts
            remainder = file_size % actual_parts
        
        max_single_part = chunk_size + (1 if remainder > 0 else 0)
        if max_part_size and max_single_part > max_part_size:
            raise ValueError(
                f"Cannot split file: would create parts of {max_single_part} bytes, "
                f"exceeding limit of {max_part_size} bytes"
            )
        
        self.log(f"Splitting {file_size:,} bytes into {actual_parts} parts...")
        self.log(f"Base chunk size: {chunk_size:,} bytes, {remainder} parts get +1 byte")
        
        parts_info = []
        base_name = os.path.basename(input_file)
        
        with open(input_file, 'rb') as f:
            for i in range(actual_parts):
                part_path = os.path.join(output_dir, f"{base_name}.part{i:03d}")
                current_chunk_size = chunk_size + (1 if i < remainder else 0)
                
                bytes_written = 0
                with open(part_path, 'wb') as part:
                    while bytes_written < current_chunk_size:
                        to_read = min(self.chunk_size, current_chunk_size - bytes_written)
                        data = f.read(to_read)
                        if not data:
                            raise ValueError(f"Unexpected end of file at part {i}")
                        part.write(data)
                        bytes_written += len(data)
                
                part_hash = self.compute_hash(part_path)
                parts_info.append((part_path, part_hash))
                
                if (i + 1) % 5 == 0 or i == actual_parts - 1:
                    self.log(f"  Created part {i+1}/{actual_parts} ({bytes_written:,} bytes)")
        
        return parts_info
    
    def merge_files(self, parts: List[str], output_file: str) -> None:
        """Merge parts into single file using chunked I/O."""
        self.log(f"Merging {len(parts)} parts...")
        
        with open(output_file, 'wb') as out:
            for i, part in enumerate(sorted(parts)):
                with open(part, 'rb') as p:
                    while chunk := p.read(self.chunk_size):
                        out.write(chunk)
                
                if (i + 1) % 5 == 0 or i == len(parts) - 1:
                    self.log(f"  Merged part {i+1}/{len(parts)}")
    
    def create_manifest(self, input_file: str, parts_info: List[Tuple[str, str]], 
                       output_path: str) -> None:
        """Create JSON manifest with file and part information."""
        manifest = {
            'original_file': os.path.basename(input_file),
            'original_size': os.path.getsize(input_file),
            'original_hash': self.compute_hash(input_file),
            'hash_algorithm': self.hash_algorithm,
            'num_parts': len(parts_info),
            'version': __version__,
            'parts': [
                {
                    'index': i,
                    'filename': os.path.basename(path),
                    'size': os.path.getsize(path),
                    'hash': part_hash
                }
                for i, (path, part_hash) in enumerate(parts_info)
            ]
        }
        
        with open(output_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        self.log(f"Manifest created: {output_path}")
    
    def verify_from_manifest(self, manifest_path: str, parts_dir: str) -> bool:
        """Verify parts against manifest."""
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        
        self.log(f"Verifying {manifest['num_parts']} parts against manifest...")
        
        for part_info in manifest['parts']:
            part_path = os.path.join(parts_dir, part_info['filename'])
            
            if not os.path.exists(part_path):
                print(f"  ✗ Part {part_info['index']}: File not found", file=sys.stderr)
                return False
            
            actual_size = os.path.getsize(part_path)
            if actual_size != part_info['size']:
                print(f"  ✗ Part {part_info['index']}: Size mismatch "
                      f"(expected {part_info['size']}, got {actual_size})", file=sys.stderr)
                return False
            
            actual_hash = self.compute_hash(part_path)
            if actual_hash != part_info['hash']:
                print(f"  ✗ Part {part_info['index']}: Hash mismatch", file=sys.stderr)
                return False
            
            self.log(f"  ✓ Part {part_info['index']}: Valid")
        
        self.log("All parts verified successfully!")
        return True

def split_mode(args):
    """Handle split operation."""
    splitter = FileSplitter(args.algorithm, args.quiet)
    
    if args.output_dir:
        output_dir = args.output_dir
    else:
        input_path = Path(args.input_file)
        output_dir = f"{input_path.name}_parts"
    
    os.makedirs(output_dir, exist_ok=True)
    
    num_parts = args.num_parts
    max_part_size = args.max_part_size_mb * 1024 * 1024 if args.max_part_size_mb else None
    
    parts_info = splitter.split_file(args.input_file, output_dir, num_parts, max_part_size)
    manifest_path = os.path.join(output_dir, "manifest.json")
    splitter.create_manifest(args.input_file, parts_info, manifest_path)
    
    if args.json:
        print(json.dumps({
            'status': 'success',
            'parts_directory': output_dir,
            'total_parts': len(parts_info),
            'manifest': manifest_path
        }))
    else:
        splitter.log(f"\nSplit complete! Parts saved to: {output_dir}")
        splitter.log(f"Total parts: {len(parts_info)}")

def merge_mode(args):
    """Handle merge operation."""
    splitter = FileSplitter(args.algorithm, args.quiet)
    manifest_path = os.path.join(args.parts_dir, "manifest.json")
    
    if os.path.exists(manifest_path):
        if not splitter.verify_from_manifest(manifest_path, args.parts_dir):
            if args.json:
                print(json.dumps({'status': 'failed', 'error': 'Part verification failed'}))
            else:
                print("\nError: Part verification failed. Aborting merge.", file=sys.stderr)
            sys.exit(1)
        
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        
        parts = [os.path.join(args.parts_dir, p['filename']) for p in manifest['parts']]
        output_file = args.output_file or manifest['original_file']
    else:
        splitter.log("Warning: No manifest found, merging all .partXXX files in order")
        part_pattern = re.compile(r'\.part\d{3}$')
        parts = sorted([
            os.path.join(args.parts_dir, f) 
            for f in os.listdir(args.parts_dir) 
            if part_pattern.search(f)
        ])
        
        if not parts:
            if args.json:
                print(json.dumps({'status': 'failed', 'error': 'No part files found'}))
            else:
                print("Error: No part files found in directory", file=sys.stderr)
            sys.exit(1)
        
        output_file = args.output_file or "merged_file"
    
    splitter.merge_files(parts, output_file)
    
    verification_passed = False
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        merged_hash = splitter.compute_hash(output_file)
        
        if args.json:
            verification_passed = merged_hash == manifest['original_hash']
        else:
            splitter.log(f"\nOriginal hash: {manifest['original_hash']}")
            splitter.log(f"Merged hash:   {merged_hash}")
            if merged_hash == manifest['original_hash']:
                splitter.log("✓ Verification passed: Files are bit-for-bit identical!")
                verification_passed = True
            else:
                print("✗ Verification failed: Hashes do not match!", file=sys.stderr)
                sys.exit(1)
    
    if args.json:
        print(json.dumps({
            'status': 'success',
            'output_file': output_file,
            'verification_passed': verification_passed
        }))
    else:
        splitter.log(f"\nMerged file: {output_file}")

def verify_mode(args):
    """Handle verification operation."""
    splitter = FileSplitter(args.algorithm, args.quiet)
    temp_dir = tempfile.mkdtemp()
    try:
        original_hash = splitter.compute_hash(args.input_file)
        splitter.log(f"Original hash ({args.algorithm}): {original_hash}")
        
        num_parts = args.num_parts
        max_part_size = args.max_part_size_mb * 1024 * 1024 if args.max_part_size_mb else None
        parts_info = splitter.split_file(args.input_file, temp_dir, num_parts, max_part_size)
        
        merged_file = os.path.join(temp_dir, f"merged_{Path(args.input_file).name}")
        splitter.merge_files([p[0] for p in parts_info], merged_file)
        
        merged_hash = splitter.compute_hash(merged_file)
        
        if args.json:
            verification_passed = original_hash == merged_hash
            print(json.dumps({
                'status': 'success' if verification_passed else 'failed',
                'original_hash': original_hash,
                'merged_hash': merged_hash,
                'verification_passed': verification_passed
            }))
        else:
            splitter.log(f"Merged hash ({args.algorithm}):   {merged_hash}")
            if original_hash == merged_hash:
                splitter.log("\n✓ Verification passed: Split-merge cycle preserves data integrity!")
            else:
                print("\n✗ Verification failed: Hashes do not match!", file=sys.stderr)
                sys.exit(1)
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(
        prog='advanced-file-splitter',
        description="Advanced file splitter with verification and flexible sizing options.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s split large_file.dat
  %(prog)s split large_file.dat -n 12
  %(prog)s split large_file.dat -s 50
  %(prog)s merge large_file.dat_parts
  %(prog)s verify large_file.dat

Version: """ + __version__
    )
    
    parser.add_argument('--version', action='version', version=f'%(prog)s {__version__}')
    
    subparsers = parser.add_subparsers(dest='mode', help='Operation mode')
    
    # Split mode
    sp = subparsers.add_parser('split', help='Split file into parts')
    sp.add_argument('input_file', help='Input file to split')
    sp.add_argument('-o', '--output-dir', help='Output directory for parts')
    sp.add_argument('-n', '--num-parts', type=int, help=f'Number of parts (default: {DEFAULT_PARTS})')
    sp.add_argument('-s', '--max-part-size-mb', type=int, help='Maximum size per part in MB')
    sp.add_argument('-a', '--algorithm', default='sha256', 
                   choices=['md5', 'sha1', 'sha256', 'sha512'],
                   help='Hash algorithm (default: sha256)')
    sp.add_argument('-q', '--quiet', action='store_true', help='Suppress progress output')
    sp.add_argument('--json', action='store_true', help='Output results as JSON')
    
    # Merge mode
    mp = subparsers.add_parser('merge', help='Merge parts back into file')
    mp.add_argument('parts_dir', help='Directory containing parts')
    mp.add_argument('-o', '--output-file', help='Output file name')
    mp.add_argument('-a', '--algorithm', default='sha256',
                   choices=['md5', 'sha1', 'sha256', 'sha512'],
                   help='Hash algorithm (default: sha256)')
    mp.add_argument('-q', '--quiet', action='store_true', help='Suppress progress output')
    mp.add_argument('--json', action='store_true', help='Output results as JSON')
    
    # Verify mode
    vp = subparsers.add_parser('verify', help='Test split-merge integrity')
    vp.add_argument('input_file', help='Input file to verify')
    vp.add_argument('-n', '--num-parts', type=int, help=f'Number of parts (default: {DEFAULT_PARTS})')
    vp.add_argument('-s', '--max-part-size-mb', type=int, help='Maximum size per part in MB')
    vp.add_argument('-a', '--algorithm', default='sha256',
                   choices=['md5', 'sha1', 'sha256', 'sha512'],
                   help='Hash algorithm (default: sha256)')
    vp.add_argument('-q', '--quiet', action='store_true', help='Suppress progress output')
    vp.add_argument('--json', action='store_true', help='Output results as JSON')
    
    args = parser.parse_args()
    
    if not args.mode:
        parser.print_help()
        sys.exit(0)
    
    try:
        if args.mode == 'split':
            if not os.path.isfile(args.input_file):
                parser.error(f"Input file not found: {args.input_file}")
            split_mode(args)
        elif args.mode == 'merge':
            if not os.path.isdir(args.parts_dir):
                parser.error(f"Parts directory not found: {args.parts_dir}")
            merge_mode(args)
        elif args.mode == 'verify':
            if not os.path.isfile(args.input_file):
                parser.error(f"Input file not found: {args.input_file}")
            verify_mode(args)
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        if hasattr(args, 'json') and args.json:
            print(json.dumps({'status': 'failed', 'error': str(e)}))
        else:
            print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

              chmod +x $out/bin/${pname}
              
              # Wrap the script to ensure Python is in PATH
              wrapProgram $out/bin/${pname} \
                --prefix PATH : ${python}/bin
            '';

            meta = with pkgs.lib; {
              description = "Advanced file splitter with verification, manifest support, and bit-perfect integrity checking";
              homepage = "https://github.com/yourusername/advanced-file-splitter";
              license = licenses.lgpl3Plus;
              maintainers = with maintainers; [ ];
              mainProgram = pname;
              platforms = platforms.all;
            };
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/${pname}";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python3
            python3Packages.pytest
            python3Packages.black
            python3Packages.mypy
          ];
          
          shellHook = ''
            echo "Advanced File Splitter Development Environment"
            echo "Python: $(python --version)"
            echo ""
            echo "Available commands:"
            echo "  python -m pytest tests/     # Run tests"
            echo "  black *.py                  # Format code"
            echo "  mypy *.py                   # Type check"
          '';
        };
      }
    );
}
