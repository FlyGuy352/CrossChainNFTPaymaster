import Link from 'next/link';

export default function Header() {
    return (
        <>
        <div>
            Cross-Chain<br/>NFT PayMaster
        </div>
        <Link href='/'>Home</Link>
        <Link href='/about'>About</Link>
        </>
    );
};