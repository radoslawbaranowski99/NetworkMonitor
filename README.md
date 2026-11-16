# Network Monitor

A macOS application built with SwiftUI for checking HTTPS responses, measuring request duration and exporting a local check history.

Created as a learning and portfolio project focused on networking, asynchronous programming, data persistence and CSV export.

## Features

- Check an HTTPS URL or enter a domain without the https:// prefix
- Display the HTTP status code and response category.
- Measure request duration in milliseconds.
- Record connection errors, including DNS failures and offline errors.
- Keep up to 100 recent checks, newest first.
- Restore check history and the last entered address after restarting.
- Search history by its displayed contents.
- Share the latest result, all checks or filtered checks as text.
- Export all structured checks to a CSV file.
- Clear history with a confirmation dialog.
- View and share older text history from the initial project version.

## Requirements

- macOS 27.2 or later.
- Xcode 27.2
- An internet connection for checking remote websites.

The application has been manually tested on macOS.  iOS support has not been tested.

## Running the Project

1. Download or clone this repository.
2. Open NetworkMonitor.xcodeproj in Xcode.
3. Select the NetworkMonitor scheme and My Mac as the destination.
4. In Signing & Capabilities > App Sandbox, enable:
	- Network > Outgoing Connections (Client).
	- File Access > User Selected File > Read/Write.
5. Build and run the application with Command + R.

## Usage 

1. Enter a domain such as example.com or a full HTTPS URL.
2. Click Check or press Return.
3. Review the status code, response category and request duration.
4. Use Check Again to repeat the last valid request.
5. Search previous results using the Search history field.
6. Open Export to share results or save all checks as CSV.

## CSV Format

The exported file uses UTF-8 encoding, comma-separated columns and quoted data fields.

| Column | Description |
| --- | --- |
| date | Check timestamp in ISO 8601 format, using UTC |
| address | Requested HTTPS URL |
| status_code | HTTP response code; empty for connection failures |
| duration_ms | Measured request duration in milliseconds |
| error | Connection error description; empty for HTTP responses |

## Implementation

- SwiftUI provides the application interface.
- URLSession performs asynchronous HTTP HEAD requests.
- ContinuousClock measures request duration.
- NetworkCheck stores each check as structured data.
- Codable and JSONEncoder/JSONDecoder handle history serialization.
- UserDefaults stores history locally.
- AppStorage remembers the last entered address.
- FileDocument and fileExporter provide CSV file export.
- ShareLink provides system text sharing.

## Manual Testing 

The following scenarios were checked during development:

- Successful HTTP responses: 200, 201, 202 and 204.
- Client and server error responses.
- Automatic redirect handling.
- DNS lookup failures.
- Requests while the internet connection is offline.
- Empty input validation.
- Prevention of overlapping checks.
- History persistence after restarting the application.
- History searching and clearing.
- History size limit.
- Text sharing.
- CSV export and cancellation of the save dialog.

## Limitations

- This application is a diagnostic tool, not a firewall or security scanner.
- Checks are started manually; there is no background monitoring.
- Only HTTPS input URLs are accepted.
- Requests use HEAD. Some servers may handle HEAD differently from GET or reject automated requests.
- URLSession follows redirects automatically. The displayed code is normally the final response, not the complete redirect chain.
- The recorded address is the requested URL, not necessarily the final URL after redirects.
- Request duration is not ICMP ping latency. It may include DNS lookup, connection setup, TLS negotiation, redirects and server processing.
- An HTTP 200 response does not prove that a website is safe or that all of its features are working.
- The request timeout interval is set to 15 seconds; this is not a guaranteed 15-second limit on total elapsed time.
- History is stored in local application settings, not an encrypted vault. 
- Storage errors are currently reported in the Xcode console.
- The application has not been tested on iOS

## Privacy

Checks contact the address entered by the user. History is stored locally by this application’s code.

Exported files can contain complete URLs, including paths and query parameters. Review exports before sharing or committing them.

## Learning Outcomes

This project provided practice with:
- Swift and SwiftUI.
- State management and bindings.
- Async/await and error handling.
- HTTP response interpretation.
- Structured data models and JSON persistence.
- Search and filtering.
- CSV generation and file export.
- Manual testing and debugging.


