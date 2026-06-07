// React Theme — extracted from https://kharis.org
// Compatible with: Chakra UI, Stitches, Vanilla Extract, or any CSS-in-JS

/**
 * TypeScript type definition for this theme:
 *
 * interface Theme {
 *   colors: {
    primary: string;
    secondary: string;
    accent: string;
    background: string;
    foreground: string;
    neutral50: string;
    neutral100: string;
    neutral200: string;
    neutral300: string;
    neutral400: string;
    neutral500: string;
    neutral600: string;
    neutral700: string;
    neutral800: string;
    neutral900: string;
 *   };
 *   fonts: {
    body: string;
 *   };
 *   fontSizes: {
    '12': string;
    '13': string;
    '14': string;
    '15': string;
    '16': string;
    '17': string;
    '18': string;
    '23': string;
    '24': string;
    '28': string;
    '42': string;
    '50': string;
 *   };
 *   space: {
    '5': string;
    '15': string;
    '30': string;
    '38': string;
    '50': string;
    '60': string;
    '64': string;
    '80': string;
    '90': string;
    '100': string;
    '109': string;
    '130': string;
    '150': string;
    '250': string;
 *   };
 *   radii: {
    sm: string;
    md: string;
    lg: string;
    xl: string;
    full: string;
 *   };
 *   shadows: {
    sm: string;
    xs: string;
    md: string;
    lg: string;
 *   };
 *   states: {
 *     hover: { opacity: number };
 *     focus: { opacity: number };
 *     active: { opacity: number };
 *     disabled: { opacity: number };
 *   };
 * }
 */

export const theme = {
  "colors": {
    "primary": "#fd7f20",
    "secondary": "#6b34fa",
    "accent": "#800654",
    "background": "#ffffff",
    "foreground": "#000000",
    "neutral50": "#7a7a7a",
    "neutral100": "#000000",
    "neutral200": "#ffffff",
    "neutral300": "#5f626a",
    "neutral400": "#32363d",
    "neutral500": "#8d8f93",
    "neutral600": "#babbc0",
    "neutral700": "#999999",
    "neutral800": "#3a4652",
    "neutral900": "#d2d2d2"
  },
  "fonts": {
    "body": "'Noto Sans', sans-serif"
  },
  "fontSizes": {
    "12": "12px",
    "13": "13px",
    "14": "14px",
    "15": "15px",
    "16": "16px",
    "17": "17px",
    "18": "18px",
    "23": "23px",
    "24": "24px",
    "28": "28px",
    "42": "42px",
    "50": "50px"
  },
  "space": {
    "5": "5px",
    "15": "15px",
    "30": "30px",
    "38": "38px",
    "50": "50px",
    "60": "60px",
    "64": "64px",
    "80": "80px",
    "90": "90px",
    "100": "100px",
    "109": "109px",
    "130": "130px",
    "150": "150px",
    "250": "250px"
  },
  "radii": {
    "sm": "3px",
    "md": "8px",
    "lg": "15px",
    "xl": "18px",
    "full": "850px"
  },
  "shadows": {
    "sm": "rgba(0, 0, 0, 0.5) 0px 0px 0px 0px",
    "xs": "rgba(0, 0, 0, 0) 0px 1px 0px 0px",
    "md": "rgba(0, 0, 0, 0.1) 0px 8px 8px 0px",
    "lg": "rgba(0, 0, 0, 0.18) 0px 0px 30px 0px"
  },
  "states": {
    "hover": {
      "opacity": 0.08
    },
    "focus": {
      "opacity": 0.12
    },
    "active": {
      "opacity": 0.16
    },
    "disabled": {
      "opacity": 0.38
    }
  }
};

// MUI v5 theme
export const muiTheme = {
  "palette": {
    "primary": {
      "main": "#fd7f20",
      "light": "hsl(26, 98%, 71%)",
      "dark": "hsl(26, 98%, 41%)"
    },
    "secondary": {
      "main": "#6b34fa",
      "light": "hsl(257, 95%, 74%)",
      "dark": "hsl(257, 95%, 44%)"
    },
    "background": {
      "default": "#ffffff",
      "paper": "#f9fafe"
    },
    "text": {
      "primary": "#000000",
      "secondary": "#7a7a7a"
    }
  },
  "typography": {
    "fontFamily": "'DM Sans', sans-serif",
    "h1": {
      "fontSize": "42px",
      "fontWeight": "700",
      "lineHeight": "50.4px"
    },
    "h2": {
      "fontSize": "24px",
      "fontWeight": "700",
      "lineHeight": "28.8px"
    },
    "h3": {
      "fontSize": "23px",
      "fontWeight": "400",
      "lineHeight": "23px"
    },
    "body1": {
      "fontSize": "18px",
      "fontWeight": "400",
      "lineHeight": "33.75px"
    }
  },
  "shape": {
    "borderRadius": 8
  },
  "shadows": [
    "rgba(0, 0, 0, 0.02) 0px 0px 0px 1px, rgba(0, 0, 0, 0.04) 0px 2px 35px 0px",
    "rgba(0, 0, 0, 0.5) 0px 0px 0px 0px",
    "rgba(0, 0, 0, 0) 0px 1px 0px 0px",
    "rgba(0, 0, 0, 0.29) 0px 0px 10px 0px",
    "rgba(0, 0, 0, 0.1) 0px 8px 8px 0px"
  ]
};

export default theme;
