export default function GreenArrow({ direction, elementType, isVisible, onClick, disabled }) {
    if (elementType === 'button') {
        return (
            <button
                className={`
                    hidden sm:inline-block w-0 h-0 border-t-12 border-b-12 border-t-transparent border-b-transparent 
                    cursor-pointer disabled:cursor-not-allowed transition-colors ${isVisible ? 'visible' : 'invisible'}
                    ${
                        direction === 'left' ? 'border-r-20  border-r-green-700 enabled:hover:border-r-green-900' : 
                        direction === 'right' ? 'border-l-20 border-l-green-700 enabled:hover:border-l-green-900' : ''
                    }
                `}
                onClick={onClick}
                disabled={disabled}
            >
            </button>
        );
    } else if (elementType === 'div') {
        return (
            <div className={`w-fit mx-auto ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}`}>
                <div onClick={onClick} className={`flex justify-center gap-1 group ${disabled ? 'pointer-events-none' : ''}`}>
                    <div
                        className={`
                            sm:hidden w-0 h-0 border-t-12 border-b-12 border-t-transparent border-b-transparent 
                            transition-colors ${isVisible ? 'visible' : 'invisible'}
                            ${
                                direction === 'left' ? 'border-r-20  border-r-green-700 group-enabled:hover:border-r-green-900' : 
                                direction === 'right' ? 'border-l-20 border-l-green-700 group-enabled:hover:border-l-green-900' : ''
                            }
                        `}
                    >
                    </div>
                    <div
                        className={`
                            sm:hidden w-0 h-0 border-t-12 border-b-12 border-t-transparent border-b-transparent 
                            transition-colors ${isVisible ? 'visible' : 'invisible'}
                            ${
                                direction === 'left' ? 'border-r-20  border-r-green-700 group-enabled:hover:border-r-green-900' : 
                                direction === 'right' ? 'border-l-20 border-l-green-700 group-enabled:hover:border-l-green-900' : ''
                            }
                        `}
                    >
                    </div>
                </div>
            </div>
        );
    }
}