import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import App from './App';

describe('App', () => {
  it('renders navigation links', () => {
    render(
      <BrowserRouter>
        <App />
      </BrowserRouter>
    );

    expect(screen.getByText('MCP')).toBeInTheDocument();
    expect(screen.getByText('Monitoring Platform')).toBeInTheDocument();
    expect(screen.getByText('Dashboard')).toBeInTheDocument();
    expect(screen.getByText('Health Check')).toBeInTheDocument();
    expect(screen.getByText('Service')).toBeInTheDocument();
  });
});