import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import Image from 'next/image';
import logoImage from '@/public/assets/images/Logo.png';

export default function Header() {
    return (
      <div className='font-BDOGrotesk'>
        <nav className='flex justify-between p-5'>
          <Link className='flex gap-1' href='/'>
            <Image
                src={logoImage}
                width={40}
                height={40}
                alt='Logo'
            />
            <div className='flex items-center font-bold text-sm leading-[0.8rem]'>
              Cross-Chain<br/>NFT PayMaster
            </div>
          </Link>
          <ConnectButton />
        </nav>
        <nav className='flex justify-center gap-72 py-20 font-bold text-[#C6BABA]'>
          <Link href='/' className='hover:text-gray-800'>Home</Link>
          <Link href='/about' className='hover:text-gray-800'>About</Link>
        </nav>
      </div>
    );
};