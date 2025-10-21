## Frontend Project Structure

This Next.js project follows a modular structure to keep the code organized and maintainable. Below is a brief description of the main folders:

- **`actions`**: Contains server-side logic for secure calculations with secret values, such as admin signing.
- **`app`**: The main application folder, containing most of the UI, pages, layouts, and route-specific code.
- **`components`**: Reusable, simple UI components such as buttons, arrows and other small elements used throughout the application.
- **`constants`**: Project constants such as contract ABIs, contract addresses, and chain configurations (e.g., chain IDs).
- **`hooks`**: Custom React hooks for commonly accessed data, such as a user’s NFT balance, or for managing state and side effects.
- **`public`**: Static assets such as images, fonts, and other publicly accessible files.
- **`utils`**: Reusable JavaScript helper functions, such as generating random numbers or decoding strings.