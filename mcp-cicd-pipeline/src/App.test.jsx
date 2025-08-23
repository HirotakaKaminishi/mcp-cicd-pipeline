import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';

describe('App', () => {
  it('renders basic component structure', () => {
    // Simple test that just verifies the test setup works
    render(<div data-testid="test">Test Component</div>);
    
    expect(screen.getByTestId('test')).toBeInTheDocument();
    expect(screen.getByText('Test Component')).toBeInTheDocument();
  });
});