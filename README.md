# Advanced File Splitter

Split large files into manageable parts with cryptographic verification and bit-perfect integrity checking.

## Quick Start

```bash
# Split file into 24 parts (default)
advanced-file-splitter split video.mp4

# Merge parts back together
advanced-file-splitter merge video.mp4_parts

# Test integrity
advanced-file-splitter verify video.mp4
```

## Installation

### Nix Flakes
```bash
nix profile install github:ALH477/AFS
```

### Manual
```bash
chmod +x advanced-file-splitter
sudo cp advanced-file-splitter /usr/local/bin/
```

## Usage Guide

### Split Files

```bash
advanced-file-splitter split [OPTIONS] FILE
```

**Common Options:**
- `-n NUM` - Split into NUM parts (e.g., `-n 12`)
- `-s MB` - Maximum MB per part (e.g., `-s 50`)
- `-o DIR` - Output directory
- `--json` - Output results as JSON (for AI/scripts)
- `-q` - Quiet mode (suppress progress)

**Examples:**
```bash
# Split into 12 equal parts
advanced-file-splitter split database.sql -n 12

# Split with max 50MB per part
advanced-file-splitter split video.mp4 -s 50

# Custom output directory
advanced-file-splitter split archive.tar.gz -o /backup/parts

# AI/script usage with JSON output
advanced-file-splitter split data.zip -n 10 --json -q
```

### Merge Parts

```bash
advanced-file-splitter merge [OPTIONS] PARTS_DIR
```

**Options:**
- `-o FILE` - Output filename
- `--json` - JSON output
- `-q` - Quiet mode

**Examples:**
```bash
# Auto-verify from manifest
advanced-file-splitter merge database.sql_parts

# Specify output file
advanced-file-splitter merge backup_parts -o restored.zip

# Script usage
advanced-file-splitter merge data_parts --json -q
```

### Verify Integrity

```bash
advanced-file-splitter verify [OPTIONS] FILE
```

Tests split-merge cycle without keeping intermediate files.

## Use Cases

### 1. Email Attachments (25MB limit)
```bash
# Split for email
advanced-file-splitter split presentation.pptx -s 24

# Send all .part files + manifest.json as attachments
# Recipient runs:
advanced-file-splitter merge presentation.pptx_parts
```

### 2. Cloud Storage Upload
```bash
# Split into 50MB chunks for reliable uploads
advanced-file-splitter split backup-2025.tar.gz -s 50 -o cloud-sync/

# Upload completes via cloud sync
# On target system:
advanced-file-splitter merge cloud-sync/ -o backup-2025.tar.gz
```

### 3. Network Transfer
```bash
# Source system
advanced-file-splitter split firmware.bin -n 10 -o transfer/

# Transfer parts individually
rsync -avz transfer/ remote:/destination/

# Destination system - auto-verifies
advanced-file-splitter merge /destination/transfer/
```

### 4. Removable Media (DVD/USB)
```bash
# Split for 25GB USB drives
advanced-file-splitter split archive.tar -s 24000 -o usb-parts/

# Copy to USB, later reconstruct
advanced-file-splitter merge usb-parts/ -o archive.tar
```

### 5. Database Backups
```bash
# Split database dump
advanced-file-splitter split prod-db.sql -n 20 -o backups/

# Verify before archival
advanced-file-splitter merge backups/ -o test-restore.sql
diff prod-db.sql test-restore.sql && echo "Verified"
```

### 6. Software Distribution
```bash
# Split for download
advanced-file-splitter split software-v2.0.iso -s 100 -o downloads/

# Users download all parts then merge
advanced-file-splitter merge downloads/
```

## AI Integration

The tool provides JSON output and predictable behavior for automation.

### Python Integration
```python
import subprocess
import json

def split_file(file_path, num_parts=24):
    """Split file and return manifest data."""
    result = subprocess.run(
        ["advanced-file-splitter", "split", file_path, 
         "-n", str(num_parts), "--json", "-q"],
        capture_output=True, text=True
    )
    
    if result.returncode == 0:
        return json.loads(result.stdout)
    else:
        raise Exception(result.stderr)

def merge_file(parts_dir):
    """Merge parts with verification."""
    result = subprocess.run(
        ["advanced-file-splitter", "merge", parts_dir, "--json", "-q"],
        capture_output=True, text=True
    )
    
    if result.returncode == 0:
        data = json.loads(result.stdout)
        return data['output_file'], data['verification_passed']
    else:
        raise Exception(result.stderr)

# Usage
info = split_file("large-file.zip", num_parts=12)
print(f"Created {info['total_parts']} parts in {info['parts_directory']}")

output, verified = merge_file(info['parts_directory'])
print(f"Merged to {output}, verified: {verified}")
```

### Manifest Structure
```json
{
  "original_file": "example.zip",
  "original_size": 524288000,
  "original_hash": "a3f8b4e9...",
  "hash_algorithm": "sha256",
  "num_parts": 24,
  "version": "1.0.0",
  "parts": [
    {
      "index": 0,
      "filename": "example.zip.part000",
      "size": 21845334,
      "hash": "c7d2f8a1..."
    }
  ]
}
```

### Decision Logic
```
Need to handle large file?
├─ Email (25MB limit) → -s 24
├─ Cloud upload → -s 50
├─ Network transfer → -n 10 to 20
├─ DVD/USB media → -s based on capacity
├─ Test integrity → use verify mode
└─ Distribute software → -s 100 to 500
```

## Features

- Split by part count or max size
- SHA-256/512, SHA-1, MD5 hash support
- JSON manifest with metadata
- Individual part verification
- Memory efficient (4MB buffer)
- Bit-perfect reconstruction
- Cross-platform compatible

## Performance

**Memory:** Constant 4MB regardless of file size  
**Disk I/O:** Sequential operations for maximum throughput

**Recommended Part Sizes:**
- Local: 100-500MB
- Network: 25-50MB  
- Email/Upload: 10-25MB

## Exit Codes

- `0` - Success
- `1` - Error (check stderr)
- `130` - User cancelled (Ctrl+C)

## Security

- Hashes verify integrity, not confidentiality
- Manifest and parts are unencrypted
- Encrypt sensitive data before splitting

## License

LGPL-3.0-or-later  
Copyright (c) 2025 DeMoD LLC

## Support

Open issues at: github.com/ALH477/advanced-file-splitter
