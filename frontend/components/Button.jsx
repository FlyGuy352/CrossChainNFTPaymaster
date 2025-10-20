export default function Button({ onClick, getButtonText, isDisabled, isLoading, spinnerColor }) {
    return (
        <button
            className='
                border border-black rounded-3xl bg-white text-xl font-semibold w-96 p-3 tracking-wide 
                disabled:bg-slate-300 disabled:border-slate-600 disabled:text-slate-700 disabled:cursor-not-allowed 
                enabled:hover:scale-[1.025] transition flex justify-center items-center gap-3
            '
            onClick={onClick}
            disabled={isDisabled}
        >
            {isLoading && (
                <span
                    className={`animate-spin h-5 w-5 border-4 border-${spinnerColor} border-t-transparent rounded-full`}
                ></span>
            )}
            {getButtonText()}
        </button>
    )
}