/**
 * Demo React Button Component
 *
 * A simple button component to demonstrate JavaScript/React documentation.
 */

import React from 'react';
import PropTypes from 'prop-types';

// Documented function with JSDoc
/**
 * Handle button click events
 * @param {Event} event - The click event
 */
function handleClick(event) {
  console.log('Button clicked!', event);
}

// Undocumented function
function processProps(props) {
  return {
    ...props,
    processed: true
  };
}

const Button = ({
  children,
  onClick,
  disabled = false,
  variant = 'primary'
}) => {
  /**
   * Renders the Button component
   * @param {Object} props - Component props
   * @param {ReactNode} props.children - Button content
   * @param {Function} props.onClick - Click handler
   * @param {boolean} props.disabled - Whether button is disabled
   * @param {string} props.variant - Button style variant
   */
  return (
    <button
      className={`btn btn-${variant}`}
      onClick={handleClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
};

Button.propTypes = {
  children: PropTypes.node.isRequired,
  onClick: PropTypes.func,
  disabled: PropTypes.bool,
  variant: PropTypes.oneOf(['primary', 'secondary', 'danger'])
};

export default Button;
