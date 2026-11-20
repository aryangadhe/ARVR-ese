"""
PID Controller with anti-windup, derivative filtering, and saturation limits.
Used by the humanoid balance and joint posture controllers.
"""

from typing import Optional


class PIDController:
    """
    Standard Proportional-Integral-Derivative controller.
    u(t) = Kp * e(t) + Ki * integral(e) + Kd * de/dt
    """

    def __init__(
        self,
        kp: float = 1.0,
        ki: float = 0.0,
        kd: float = 0.0,
        min_output: float = -1.0,
        max_output: float = 1.0,
        integral_limit: Optional[float] = None,
        derivative_filter_alpha: float = 0.8,
    ):
        self.kp = float(kp)
        self.ki = float(ki)
        self.kd = float(kd)
        self.min_output = float(min_output)
        self.max_output = float(max_output)

        # Anti-windup limit for integral term
        self.integral_limit = (
            float(integral_limit) if integral_limit is not None else (self.max_output - self.min_output)
        )
        self.derivative_filter_alpha = float(derivative_filter_alpha)

        self.integral = 0.0
        self.prev_error = 0.0
        self.prev_derivative = 0.0
        self.has_prev_error = False

    def update(self, error: float, dt: float) -> float:
        """
        Compute control action given error = (setpoint - measured_value) and time delta dt.
        """
        if dt <= 1e-6:
            return 0.0

        # Proportional term
        p_term = self.kp * error

        # Integral term with anti-windup clamping
        self.integral += error * dt
        if self.integral_limit > 0:
            self.integral = max(-self.integral_limit, min(self.integral, self.integral_limit))
        i_term = self.ki * self.integral

        # Derivative term with first-order filter
        if self.has_prev_error:
            raw_derivative = (error - self.prev_error) / dt
            derivative = (
                self.derivative_filter_alpha * self.prev_derivative
                + (1.0 - self.derivative_filter_alpha) * raw_derivative
            )
        else:
            derivative = 0.0
            self.has_prev_error = True

        self.prev_error = error
        self.prev_derivative = derivative
        d_term = self.kd * derivative

        # Total unconstrained output
        output = p_term + i_term + d_term

        # Clamp output to saturation bounds
        return max(self.min_output, min(output, self.max_output))

    def reset(self):
        """Reset internal accumulator states."""
        self.integral = 0.0
        self.prev_error = 0.0
        self.prev_derivative = 0.0
        self.has_prev_error = False

    def set_gains(self, kp: Optional[float] = None, ki: Optional[float] = None, kd: Optional[float] = None):
        """Update PID gains dynamically."""
        if kp is not None:
            self.kp = float(kp)
        if ki is not None:
            self.ki = float(ki)
        if kd is not None:
            self.kd = float(kd)
