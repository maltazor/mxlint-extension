import { type PropsWithChildren, useCallback, useEffect, useMemo, useState } from 'react';
import { ThemeContext, type Theme } from './ThemeContext';

export interface ThemeProviderProps {
  /** Default theme to use if API fetch fails */
  defaultTheme?: Theme;
}

export const ThemeProvider = ({
  children,
  defaultTheme = 'light',
}: PropsWithChildren<ThemeProviderProps>) => {
  const [theme, setThemeState] = useState<Theme>(defaultTheme);

  // Apply theme to DOM
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  const setTheme = useCallback((newTheme: Theme) => {
    if (newTheme === 'dark' || newTheme === 'light') {
      setThemeState(newTheme);
    }
  }, []);

  // Fetch theme from Studio Pro API on mount
  useEffect(() => {
    const fetchTheme = async () => {
      try {
        const response = await fetch('./api/theme');
        if (!response.ok) {
          return;
        }
        const data = await response.json();

        if (data.theme === 'dark' || data.theme === 'light') {
          setThemeState(data.theme);
        }
      } catch {
        // Keep default light theme on error
      }
    };

    void fetchTheme();
  }, []);

  const value = useMemo(
    () => ({ theme, setTheme }),
    [theme, setTheme]
  );

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
};
