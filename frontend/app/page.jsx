import MintSection from './mintSection';
import TransactionSection from './transactionSection';
import { Toaster } from 'sonner';

export default function Page() {
  return (
    <>
      <Toaster richColors position='top-center'/>
      <div className='grid lg:grid-cols-2'>
        <MintSection/>
        <TransactionSection/>
      </div>
    </>
  );
};