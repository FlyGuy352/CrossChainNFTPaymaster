import MintSection from './mintSection';
import CounterSection from './counterSection';
import { Toaster } from 'sonner';

export default function Page() {
  return (
    <>
      <Toaster richColors position='top-center'/>
      <div className='grid md:grid-cols-2'>
        <MintSection/>
        <CounterSection/>
      </div>
    </>
  );
};