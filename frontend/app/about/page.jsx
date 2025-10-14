import Image from 'next/image';
import portraitImage from '@/public/assets/images/Portrait.png';

export default function Page() {

    return (
        <div>
            <Image
                src={portraitImage}
                width={261}
                height={327}
                alt='Avatar'
                className='mx-auto lg:mx-2 xl:mx-0'
            />
            <div>
                Tom Lin is a developer based in Singapore.
            </div>
        </div>
    );
}