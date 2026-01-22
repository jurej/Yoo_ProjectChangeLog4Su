# Yoo_ProjectChangeLog4Su

A SketchUp plugin that automatically prompts you to log changes every time you save your model, creating a comprehensive project history with timestamps and usernames.

## Features

- 📝 **Automatic Change Prompts** - Dialog appears automatically after each save
- 👤 **User Tracking** - Logs username with each commit for multi-user projects
- ⏰ **Timestamped Entries** - Every change is recorded with date and time
- 🚀 **Push to Master** - Save working versions to a master file (like git push) for Layout compatibility
- ⚙️ **Settings Dialog** - Configure master file path and preferences
- 📊 **Table History Viewer** - View your entire project history in a clean, organized table
- 💾 **CSV Storage** - Logs saved as `.csv` files alongside your `.skp` files for easy export and analysis
- 🔍 **Searchable Data** - CSV format allows filtering and sorting in Excel or other tools

## Installation

### Method 1: Extension Warehouse (Recommended)
*Coming soon*

### Method 2: Manual Installation

1. **Download the plugin**
   - Download the latest release from the [Releases](../../releases) page
   - Or clone this repository

2. **Locate SketchUp Plugins folder**
   - Windows: `C:\Users\[YourUsername]\AppData\Roaming\SketchUp\SketchUp [Version]\SketchUp\Plugins\`
   - macOS: `~/Library/Application Support/SketchUp [Version]/SketchUp/Plugins/`

3. **Install files**
   - Copy the entire `Yoo_ProjectChangeLog4Su` folder to your Plugins directory
   - Copy `Yoo_ProjectChangeLog4Su.rb` to your Plugins directory

4. **Restart SketchUp**
   - The plugin will load automatically on startup

## Usage

### Logging Changes

1. **Work on your model** as usual
2. **Save your model** (File > Save or Ctrl+S / Cmd+S)
3. **Change log dialog appears** automatically
4. **Enter your changes** in the text area
   ```
   - Added roof structure
   - Updated materials on walls
   - Fixed layer organization
   ```
5. **Click "Log Change"** to save the entry
   - Or click "Skip" if you don't want to log this save

> [!NOTE]
> If you have **autosave enabled** in SketchUp's preferences, the commit log dialog will also appear after each autosave event. You can click "Skip" for autosaves and only log intentional save points, or you can use it to create automatic checkpoints at regular intervals.

### History Viewer

Access your project history by going to **Plugins > View Project Change Log**

The history is displayed in a professional table format with:
- **Timestamp** column showing when each change was made
- **User** column identifying who made the change
- **Message** column with the detailed description
- Newest entries appear at the top
- Sticky headers that stay visible when scrolling
- Zebra-striped rows for easy reading

### CSV Storage Format

Log files are stored in CSV format with three columns:
```csv
"2025-11-25 11:53:03","JohnDoe","- Added new windows to facade
- Updated door placements"
```

This format allows you to:
- Open and analyze logs in Excel, Google Sheets, or other spreadsheet tools
- Filter and sort by date, user, or message content
- Export data for reports or project documentation
- Integrate with other tools and workflows

## Example History Table

When you open the history viewer, you'll see a table like this:

| Timestamp           | User  | Message                                              |
|---------------------|-------|------------------------------------------------------|
| 2025-11-21 15:20:33 | Alice | - Applied materials to walls<br>- Fixed alignment issues |
| 2025-11-21 10:05:45 | Bob   | - Added roof structure<br>- Created chimney detail   |
| 2025-11-20 14:32:10 | Alice | - Added exterior walls<br>- Placed windows and doors |
| 2025-11-20 09:15:23 | Alice | - Initial model setup<br>- Created basic floor plan  |

## Benefits

- **Track Progress** - See exactly what was done and when
- **Team Collaboration** - Know who made which changes in shared projects
- **Project Documentation** - Automatic documentation of your modeling process
- **Version Context** - Understand the evolution of your design
- **Client Communication** - Share progress updates easily

## Compatibility

- **SketchUp Version**: 2017 and later
- **Operating System**: Windows and macOS
- **Ruby Version**: 2.x and later

## Support

Having issues? Please [open an issue](../../issues) on GitHub with:
- SketchUp version
- Operating system
- Description of the problem
- Steps to reproduce

## License

Copyright © 2024

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Changelog

### Version 1.3.0 (2026-01-22)
- ✨ Allow setting skip threshold to 0 to disable prompt skipping
- 🔧 Improved validation for skip threshold input field

### Version 1.2.0 (2025-12-02)
- 🎉 **Major Update**: Converted changelog from text to CSV format
- 📊 New table-based history viewer with sortable columns
- ✨ Professional UI with sticky headers and zebra striping
- 📈 CSV files can now be opened in Excel/Google Sheets for advanced analysis
- 🔄 Improved data structure: Timestamp, User, Message columns
- 🎨 Enhanced visual design with better readability

### Version 1.1.1 (2025-11-28)
- Added RuboCop configuration for code quality
- Updated documentation for autosave feature

### Version 1.1.0 (2025-11-25)
- Added Push to Master feature
- Added Settings dialog for master file configuration
- Refactored dialogs with Trimble Modus design system
- Fixed duplicate dialog issue with singleton observers
- Improved UI consistency and styling

### Version 1.0.0 (2025-11-25)
- Initial release
- Automatic change log prompts on save
- Username tracking in log entries
- Project history viewer and editor
- Timestamped entries

## Author

Created with ❤️ for the SketchUp community

---

**Star this repository** if you find it useful! ⭐
