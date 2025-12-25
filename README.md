# Advanced File Splitter

A robust command-line utility for splitting large files into manageable parts with cryptographic verification and bit-perfect integrity checking.

## Features

- **Flexible Splitting Strategies**: Split by part count or maximum part size
- **Cryptographic Verification**: SHA-256, SHA-512, SHA-1, and MD5 hash support
- **Manifest System**: JSON metadata tracking for reliable reconstruction
- **Individual Part Verification**: Each part is hashed during creation
- **Memory Efficient**: Chunked I/O for handling files of any size
- **Bit-Perfect Integrity**: Guarantees exact reconstruction of original files

## Installation

### Using Nix Flakes

```bash
nix profile install github:yourusername/advanced-file-splitter
```

### From Source

```bash
git clone https://github.com/yourusername/advanced-file-splitter
cd advanced-file-splitter
nix build
./result/bin/advanced-file-splitter --version
```

### Traditional Installation

```bash
chmod +x advanced-file-splitter
sudo cp advanced-file-splitter /usr/local/bin/
```

## Quick Start

```bash
# Split a file into 24 parts (default)
advanced-file-splitter split largefile.zip

# Merge parts back together
advanced-file-splitter merge largefile.zip_parts

# Verify split-merge integrity
advanced-file-splitter verify largefile.zip
```

## Usage

### Split Mode

Split a file into multiple parts with various options.

```bash
advanced-file-splitter split [OPTIONS] INPUT_FILE
```

**Options:**
- `-o, --output-dir DIR` - Output directory for parts (default: INPUT_FILE_parts)
- `-n, --num-parts N` - Number of parts to create
- `-s, --max-part-size-mb MB` - Maximum size per part in megabytes
- `-a, --algorithm ALGO` - Hash algorithm: md5, sha1, sha256 (default), sha512

**Examples:**

```bash
# Split into 12 equal parts
advanced-file-splitter split database.sql -n 12

# Split with maximum 50MB per part
advanced-file-splitter split video.mp4 -s 50

# Split to custom directory with SHA-512
advanced-file-splitter split archive.tar.gz -o /backup/parts -a sha512
```

### Merge Mode

Reconstruct the original file from parts with automatic verification.

```bash
advanced-file-splitter merge [OPTIONS] PARTS_DIR
```

**Options:**
- `-o, --output-file FILE` - Output file name (default: from manifest)
- `-a, --algorithm ALGO` - Hash algorithm for verification

**Examples:**

```bash
# Merge with automatic verification
advanced-file-splitter merge database.sql_parts

# Merge to specific output file
advanced-file-splitter merge backup_parts -o restored.zip
```

### Verify Mode

Test the integrity of split-merge operations without keeping intermediate files.

```bash
advanced-file-splitter verify [OPTIONS] INPUT_FILE
```

**Options:**
- `-n, --num-parts N` - Number of parts for testing
- `-s, --max-part-size-mb MB` - Maximum part size for testing
- `-a, --algorithm ALGO` - Hash algorithm to use

**Examples:**

```bash
# Verify default split-merge cycle
advanced-file-splitter verify important.dat

# Verify with specific part count
advanced-file-splitter verify backup.tar -n 8
```

## Use Cases

### Email Attachment Distribution

Many email servers limit attachment sizes to 25MB. Split large files for email distribution.

```bash
# Split presentation into email-friendly parts
advanced-file-splitter split presentation.pptx -s 24

# Recipient merges the parts
advanced-file-splitter merge presentation.pptx_parts
```

### Cloud Storage Upload

Improve reliability of large uploads by splitting into smaller chunks that can be retried independently.

```bash
# Split 5GB backup into 50MB parts
advanced-file-splitter split backup-2025.tar.gz -s 50 -o cloud-upload/

# After upload, verify integrity on target system
advanced-file-splitter merge cloud-upload/ -o backup-2025.tar.gz
```

### Network Transfer with Integrity Checking

Transfer files across unreliable networks with built-in verification.

```bash
# On source system
advanced-file-splitter split firmware.bin -n 10 -o transfer/

# Transfer parts individually via rsync, scp, or sftp
rsync -avz transfer/ remote:/destination/

# On destination system
advanced-file-splitter merge /destination/transfer/
```

### Archival Storage

Split large archives for storage on media with size constraints (DVD, USB drives).

```bash
# Split 100GB archive for 25GB flash drives
advanced-file-splitter split photo-archive.tar -s 24000 -o usb-parts/

# Later reconstruction
advanced-file-splitter merge usb-parts/ -o photo-archive.tar
```

### Database Backup Distribution

Distribute large database dumps across multiple storage locations.

```bash
# Split production database backup
advanced-file-splitter split prod-db-2025-01.sql -n 20 -o backups/

# Verify parts before archival
advanced-file-splitter merge backups/ -o test-restore.sql
diff prod-db-2025-01.sql test-restore.sql && echo "Backup verified"
```

### Software Distribution

Package large software releases into downloadable parts.

```bash
# Split software package
advanced-file-splitter split software-v2.0.iso -s 100 -o downloads/

# Users download all parts, then merge
advanced-file-splitter merge downloads/
```

## Manifest Format

Each split operation creates a `manifest.json` file containing:

```json
{
  "original_file": "example.zip",
  "original_size": 524288000,
  "original_hash": "a3f8...",
  "hash_algorithm": "sha256",
  "num_parts": 24,
  "version": "1.0.0",
  "parts": [
    {
      "index": 0,
      "filename": "example.zip.part000",
      "size": 21845334,
      "hash": "b4e9..."
    }
  ]
}
```

This manifest enables:
- Verification of individual parts before merging
- Recovery information if parts are corrupted
- Automated reconstruction on any system

## Performance Considerations

- **Memory Usage**: Constant 4MB buffer regardless of file size
- **Hash Computation**: Optimized for large files with chunked reading
- **Disk I/O**: Sequential read/write operations for maximum throughput
- **Part Size**: Smaller parts increase overhead; larger parts reduce parallelism

Recommended part sizes:
- Local operations: 100-500MB parts
- Network transfer: 25-50MB parts
- Email/web upload: 10-25MB parts

## Error Handling

The utility performs comprehensive validation:

- File existence and accessibility checks
- Part integrity verification before merge
- Hash mismatch detection with clear error messages
- Incomplete part detection during merge operations

All errors return appropriate exit codes:
- `0`: Success
- `1`: Error (with descriptive message)
- `130`: User cancellation (Ctrl+C)

## Security Considerations

- Hash algorithms provide integrity verification, not encryption
- Manifest files are plain JSON and should be protected accordingly
- Part files contain unencrypted data from the original file
- For sensitive data, encrypt before splitting or encrypt individual parts

## License

LGPL-3.0-or-later

Copyright (c) 2025 DeMoD LLC

This library is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

## Contributing

Contributions are welcome. Please ensure:
- Code follows existing style conventions
- All tests pass before submitting
- Documentation is updated for new features
- Commit messages are clear and descriptive

## Support

For issues, questions, or feature requests, please open an issue on the project repository.

## Changelog

### Version 1.0.0
- Initial release
- Support for flexible part sizing
- Manifest-based verification system
- Three operation modes: split, merge, verify
- Multiple hash algorithm support
- Cross-platform compatibility
