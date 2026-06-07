/** @type {import('tailwindcss').Config} */
export default {
  theme: {
    extend: {
    colors: {
        primary: {
            '50': 'hsl(26, 98%, 97%)',
            '100': 'hsl(26, 98%, 94%)',
            '200': 'hsl(26, 98%, 86%)',
            '300': 'hsl(26, 98%, 76%)',
            '400': 'hsl(26, 98%, 64%)',
            '500': 'hsl(26, 98%, 50%)',
            '600': 'hsl(26, 98%, 40%)',
            '700': 'hsl(26, 98%, 32%)',
            '800': 'hsl(26, 98%, 24%)',
            '900': 'hsl(26, 98%, 16%)',
            '950': 'hsl(26, 98%, 10%)',
            DEFAULT: '#fd7f20'
        },
        secondary: {
            '50': 'hsl(257, 95%, 97%)',
            '100': 'hsl(257, 95%, 94%)',
            '200': 'hsl(257, 95%, 86%)',
            '300': 'hsl(257, 95%, 76%)',
            '400': 'hsl(257, 95%, 64%)',
            '500': 'hsl(257, 95%, 50%)',
            '600': 'hsl(257, 95%, 40%)',
            '700': 'hsl(257, 95%, 32%)',
            '800': 'hsl(257, 95%, 24%)',
            '900': 'hsl(257, 95%, 16%)',
            '950': 'hsl(257, 95%, 10%)',
            DEFAULT: '#6b34fa'
        },
        accent: {
            '50': 'hsl(322, 91%, 97%)',
            '100': 'hsl(322, 91%, 94%)',
            '200': 'hsl(322, 91%, 86%)',
            '300': 'hsl(322, 91%, 76%)',
            '400': 'hsl(322, 91%, 64%)',
            '500': 'hsl(322, 91%, 50%)',
            '600': 'hsl(322, 91%, 40%)',
            '700': 'hsl(322, 91%, 32%)',
            '800': 'hsl(322, 91%, 24%)',
            '900': 'hsl(322, 91%, 16%)',
            '950': 'hsl(322, 91%, 10%)',
            DEFAULT: '#800654'
        },
        'neutral-50': '#7a7a7a',
        'neutral-100': '#000000',
        'neutral-200': '#ffffff',
        'neutral-300': '#5f626a',
        'neutral-400': '#32363d',
        'neutral-500': '#8d8f93',
        'neutral-600': '#babbc0',
        'neutral-700': '#999999',
        'neutral-800': '#3a4652',
        'neutral-900': '#d2d2d2',
        background: '#ffffff',
        foreground: '#000000'
    },
    fontFamily: {
        sans: [
            'Maven Pro',
            'sans-serif'
        ],
        body: [
            'Noto Sans',
            'sans-serif'
        ]
    },
    fontSize: {
        '0': [
            '0px',
            {
                lineHeight: '0px'
            }
        ],
        '12': [
            '12px',
            {
                lineHeight: '76px'
            }
        ],
        '13': [
            '13px',
            {
                lineHeight: '0px'
            }
        ],
        '14': [
            '14px',
            {
                lineHeight: '14px'
            }
        ],
        '15': [
            '15px',
            {
                lineHeight: '15px'
            }
        ],
        '16': [
            '16px',
            {
                lineHeight: '18.4px'
            }
        ],
        '17': [
            '17px',
            {
                lineHeight: '31.875px'
            }
        ],
        '18': [
            '18px',
            {
                lineHeight: '33.75px'
            }
        ],
        '23': [
            '23px',
            {
                lineHeight: '23px'
            }
        ],
        '24': [
            '24px',
            {
                lineHeight: '28.8px',
                letterSpacing: '-0.648px'
            }
        ],
        '28': [
            '28px',
            {
                lineHeight: '25.2px'
            }
        ],
        '42': [
            '42px',
            {
                lineHeight: '50.4px',
                letterSpacing: '-1.134px'
            }
        ],
        '50': [
            '50px',
            {
                lineHeight: '50px'
            }
        ]
    },
    spacing: {
        '15': '30px',
        '19': '38px',
        '25': '50px',
        '30': '60px',
        '32': '64px',
        '40': '80px',
        '45': '90px',
        '50': '100px',
        '65': '130px',
        '75': '150px',
        '125': '250px',
        '5px': '5px',
        '15px': '15px',
        '109px': '109px'
    },
    borderRadius: {
        sm: '3px',
        md: '8px',
        lg: '15px',
        xl: '18px',
        full: '850px'
    },
    boxShadow: {
        sm: 'rgba(0, 0, 0, 0.5) 0px 0px 0px 0px',
        xs: 'rgba(0, 0, 0, 0) 0px 1px 0px 0px',
        md: 'rgba(0, 0, 0, 0.1) 0px 8px 8px 0px',
        lg: 'rgba(0, 0, 0, 0.18) 0px 0px 30px 0px'
    },
    screens: {
        '569px': '569px',
        sm: '640px',
        md: '782px',
        '881px': '881px',
        lg: '1025px',
        '2xl': '1600px'
    },
    transitionDuration: {
        '0': '0s',
        '100': '0.1s',
        '150': '0.15s',
        '200': '0.2s',
        '250': '0.25s',
        '270': '0.27s',
        '300': '0.3s',
        '350': '0.35s',
        '400': '0.4s',
        '450': '0.45s',
        '500': '0.5s',
        '600': '0.6s'
    },
    transitionTimingFunction: {
        custom: 'cubic-bezier(0.4, 0, 0.21, 0.99)',
        default: 'ease',
        linear: 'linear'
    },
    container: {
        center: true,
        padding: '0px'
    },
    maxWidth: {
        container: '1280px'
    }
},
  },
};
