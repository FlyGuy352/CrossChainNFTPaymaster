import './globals.css';
import '@rainbow-me/rainbowkit/styles.css';
import Header from './header';
import Providers from './providers';
import Footer from './footer';

export const metadata = {
  title: "Cross-Chain NFT Paymaster",
  description: "Mint a NFT on Hedera and enjoy gasless transactions on Ethereum",
};

export default function RootLayout({ children }) {
  return (
    <html lang='en'>
      <body>
        <Providers>
          <div className='min-h-screen'>
            <Header />
              <main>
                {children}
              </main>
            <Footer />
          </div>
        </Providers>
      </body>
    </html>
  );
}