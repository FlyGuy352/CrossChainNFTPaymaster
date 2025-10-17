import Image from 'next/image';
import portraitImage from '@/public/assets/images/Portrait.jpg';

export default function Page() {

    return (
        <div className='bg-slate-100 grid sm:grid-cols-2 gap-y-5 md:w-4/5 lg:w-3/5 xl:w-1/2 mx-3 md:mx-auto p-3 rounded-xl mb-10'>
            <Image
                src={portraitImage}
                width={261}
                height={327}
                alt='Avatar'
                className='mx-auto lg:mx-2 xl:mx-0'
            />
            <div>
                <p className='font-bold text-center text-lg mb-5'>Tom Lin</p>
                <p className='leading-tight'>
                    Tom Lin is a senior developer based in Singapore. He has a wide range of technical interests including blockchain, cloud computing, programming languages, and AI.
                    <br/><br/>
                    He dreams of one day quitting his day job and travelling for a living, together with his wife and four year old son.
                </p>
            </div>
        </div>
    );
}